#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

SRCDIR=${0%/*}
ROOTFS_DATA_SIZE=
SECURE=false

die () {
    echo "$@" >&2
    exit 1
}

usage() {
	echo "mksdimg.sh [-s] [-r <size MiB> ] [-h] <image>" >&2
	echo "  -s: Secure boot" >&2
	echo "  -r: rootfs_data size in MiB" >&2
	echo "  -h: Show this help" >&2
    echo "  <image> is the image file to create"
	exit 1
}

while getopts sr:f:h name; do
    case ${name} in
    r)  ROOTFS_DATA_SIZE=${OPTARG} 
		if ! [ "${ROOTFS_DATA_SIZE}" -eq "${ROOTFS_DATA_SIZE}" ] 2>/dev/null; then
			echo "rootfs_data size is not a number" >&2
			exit 1
		fi
		;;
	f)  SRCDIR=${OPTARG} ;;
    s)  SECURE=true ;;
    ?)  usage ;;
    esac
done
shift $((OPTIND - 1))

TARGET="${1}"

[ -n "${TARGET}" ] || usage

set -e

# Specify partition sizes in MiB
PART_SIZE=1
BOOT_SIZE=48
SWAP_SIZE=256
PERM_SIZE=48

{ [ -f "${SRCDIR}/rootfs.bin" ] || [ -f "${SRCDIR}/kernel.itb" ]; } && \
	boot_only=false || boot_only=true

if ${boot_only}; then
	# Calculate total image size
	IMAGE_SIZE=$(( BOOT_SIZE + PART_SIZE ))
else
	# Calculate rootfs size
	ROOTFS_SIZE=$(stat -c %s "$(realpath "${SRCDIR}/rootfs.bin")")
	# Align rootfs size to 1MiB
	ROOTFS_SIZE=$(( ROOTFS_SIZE / (1024 * 1024) + 1 ))

	# Set rootfs_data size to 25% of the rootfs size or 256 MiB
	# whatever is greater by default
	if [ -z "${ROOTFS_DATA_SIZE}" ]; then
		# Set rootfs_data size to 25% of the rootfs size
		ROOTFS_DATA_SIZE=$(( ROOTFS_SIZE / 4 ))
		# Set rootfs_data size 256 MiB if smaller
		ROOTFS_DATA_SIZE=$(( ROOTFS_DATA_SIZE > 256 ? ROOTFS_DATA_SIZE : 256 ))
	fi

	# Calculate total image size
	IMAGE_SIZE=$(( BOOT_SIZE + SWAP_SIZE + PERM_SIZE + ROOTFS_SIZE + ROOTFS_DATA_SIZE + 3 * PART_SIZE ))
fi

# Append partition image to disk image
append_image() {
	dd if="${2}" of="${TARGET_TMP}" bs=512 seek="${1}" conv=notrunc status=none
}

# Create ext4 file system image
make_ext4() {
	mkfs.ext4 -q -F -m 1 -L "${1}" \
		-E root_owner=0:0,lazy_itable_init=0,lazy_journal_init=0 \
		-O encrypt,ext_attr "${2}" "${3}" > /dev/null
}

# Create ext4 partition
create_ext4_partition() {
	echo "[Creating \"${2}\" partition...]"

	EXT4_PART="${TMPDIR}/${2}.part"

	# Format ext4 partition image
	make_ext4 "${2}" "${EXT4_PART}" "${3}M"

	# Add ext4 partition to disk image
	append_image "${1}" "${EXT4_PART}"

	# Remove ext4 partition image
	rm -f "${EXT4_PART}"
}

# Create boot partition
create_boot_partition() {
	echo "[Creating \"boot\" partition...]"

	BOOT_PART="${TMPDIR}/boot.part"

	# Format boot partition
	mkfs.vfat -F 32 -n BOOT -C "${BOOT_PART}" $(( BOOT_SIZE * 1024 )) > /dev/null

	${SECURE} && EXT="cip" || EXT="bin"

	# Copy files to boot partition
	mcopy -i "${BOOT_PART}" \
		"${SRCDIR}/boot.${EXT}" \
		"${SRCDIR}/u-boot.itb" \
		"${SRCDIR}/uboot.env" \
		::/

	${boot_only} ||
		mcopy -i "${BOOT_PART}" "${SRCDIR}/kernel.itb" ::\

	# Add boot partition to disk image
	append_image "${1}" "${BOOT_PART}"

	# Remove boot partition image
	rm -f "${BOOT_PART}"
}

# Create swap partition
create_swap_partition() {
	echo "[Creating \"swap\" partition...]"

	SWAP_PART="${TMPDIR}/swap.part"

	# Create swap partition image
	fallocate -l ${SWAP_SIZE}MiB "${SWAP_PART}"
	chmod 600 "${SWAP_PART}"

	# Format swap partition image
	mkswap -L swap "${SWAP_PART}" > /dev/null

	# Add swap partition to disk image
	append_image "${1}" "${SWAP_PART}"

	# Remove swap partition image
	rm -f "${SWAP_PART}"
}

# Create rootfs partition
create_rootfs_partition() {
	echo "[Creating \"rootfs_a\" partition...]"

	append_image "${1}" "${SRCDIR}/rootfs.bin"
}

trap 'rm -rf ${TMPDIR}' EXIT

TMPDIR=$(mktemp -d -t mksdimg.XXXXXX)
TARGET_TMP=${TMPDIR}/${TARGET##*/}

echo "[Creating SD card image...]"

# Create disk image
fallocate -l ${IMAGE_SIZE}M "${TARGET_TMP}"

# Create image partition table
if ${boot_only}; then
	printf ',%sM,0xc,*\n' ${BOOT_SIZE} | \
		sfdisk -q "${IMGTMPFILE}"
else
	printf ',%sM,0xc,*\n,%sM,S\n,%sM,L\n,-,Ex\n,%sM,L\n,-,L\n' \
		${BOOT_SIZE} ${SWAP_SIZE} ${PERM_SIZE} "${ROOTFS_SIZE}" | \
		sfdisk -q "${TARGET_TMP}"
fi

# Read partition table and create partitions
sfdisk -qlo device,start "${TARGET_TMP}" |
while read -r DEVICE START; do
	case ${DEVICE#"${TARGET_TMP}"} in
		1) create_boot_partition "${START}" ;;
		2) create_swap_partition "${START}" ;;
		3) create_ext4_partition "${START}" "perm" "${PERM_SIZE}" ;;
		5) create_rootfs_partition "${START}" ;;
		6) create_ext4_partition "${START}" "rootfs_data_a" "${ROOTFS_DATA_SIZE}" ;;
	esac
done

# Create sparse image
fallocate -d "${TARGET_TMP}"

# Create bmap file
if command -v bmaptool > /dev/null; then
	echo "[Creating bmap file...]"
	bmaptool create -o "${TARGET}.bmap" "${TARGET_TMP}"
fi

echo "[Compressing SD card image...]"
xz -9cqT 0 "${TARGET_TMP}" > "${TARGET}.xz"

echo "[Image file: ${TARGET}.xz]"
echo "SD Card Programming, example using dd or bmaptool:"
echo "  umount /dev/sdX? ; xz -dc ${TARGET}.xz | sudo dd of=/dev/sdX bs=4M conv=fsync"
if [ -f "${TARGET}.bmap" ]; then
	echo "  umount /dev/sdX? ; bmaptool copy ${TARGET}.xz /dev/sdX"
fi

# Remove temporary directory
rm -rf "${TMPDIR}"

# Flush file system buffers
sync

echo "[Done]"
