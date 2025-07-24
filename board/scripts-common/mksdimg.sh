#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

SRCDIR=$(dirname "${0}")
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
	echo "  -b: boot size in MiB" >&2
	echo "  -p: perm size in MiB" >&2
	echo "  -w: swap size in MiB" >&2
	echo "  -h: Show this help" >&2
    echo "  <image> is the image file to create"
	exit 1
}

check_present() {
	for i in "${@}"; do
		which "${i}" > /dev/null || die "${i} utility not found"
	done
}

while getopts sr:b:p:w:f:h name; do
    case ${name} in
    r)  ROOTFS_DATA_SIZE=${OPTARG} 
		if ! [ "${ROOTFS_DATA_SIZE}" -eq "${ROOTFS_DATA_SIZE}" ] 2>/dev/null; then
			echo "rootfs_data size is not a number" >&2
			exit 1
		fi
		;;
    b)  BOOT_SIZE=${OPTARG} ;;
    p)  PERM_SIZE=${OPTARG} ;;
	w)  SWAP_SIZE=${OPTARG} ;;
	f)  SRCDIR=${OPTARG} ;;
	s)  SECURE=true ;;
	?)  usage ;;
	esac
done
shift $((OPTIND - 1))

TARGET="${1}"

[ -n "${TARGET}" ] || usage

check_present sfdisk mkfs.ext4 mkfs.vfat mkswap mcopy dd

set -e

# Specify partition sizes in MiB
PART_SIZE=1
BOOT_SIZE=${BOOT_SIZE:-48}
SWAP_SIZE=${SWAP_SIZE:-256}
PERM_SIZE=${PERM_SIZE:-256}

find_file() {
	for f in $(ls -1 -t "${SRCDIR}"/${1} 2> /dev/null);
	do
		[ -L "${f}" ] || { echo "${f}"; break; }
	done
}

cleanup() {
	e=$?
	rm -rf "${WORKDIR_TMP}"
	exit ${e}
}

trap 'cleanup' EXIT INT TERM

WORKDIR_TMP=$(mktemp -d -t mksdimg.XXXXXX)

ROOTFS_PATH=${SRCDIR}/rootfs.bin

if [ ! -f "${ROOTFS_PATH}" ] && [ ! -f "${SRCDIR}/u-boot.itb" ]; then
	SWU_PATH=$(find_file '*.swu')
	if [ -n "${SWU_PATH}" ]; then
		SRCDIR=${WORKDIR_TMP}/swu_src
		cpio -idm --quiet < "${SWU_PATH}" -D "${SRCDIR}"
		ROOTFS_PATH=${SRCDIR}/rootfs.bin
	else
		die 'Nothing to load'
	fi
fi

if [ -f "${ROOTFS_PATH}" ]; then
	boot_only=false 
else
	boot_only=true
fi

[ -f "${SRCDIR}/flash.bin" ] && FS_OFFSET=8 || FS_OFFSET=1

if ! ${boot_only}; then
	# Calculate rootfs size
	ROOTFS_SIZE=$(stat -L -c %s "${ROOTFS_PATH}")
	# Align rootfs size to 1MiB
	ROOTFS_SIZE=$(( ROOTFS_SIZE / (1024 * 1024) + 1 ))

	# Set rootfs size to image size or 48 MiB
	# whatever is greater by default
	ROOTFS_SIZE=$(( ROOTFS_SIZE > 48 ? ROOTFS_SIZE : 48 ))

	if [ -z "${ROOTFS_DATA_SIZE}" ]; then
		# Set rootfs_data size to 25% or 256 MiB if smaller
		ROOTFS_DATA_SIZE=$(( ROOTFS_DATA_SIZE > 1024 ? ROOTFS_DATA_SIZE / 4 : 256 ))
	fi

	# Calculate total image size
	EXT_OFFS=$(( FS_OFFSET + BOOT_SIZE + SWAP_SIZE + PERM_SIZE ))
	IMAGE_SIZE=$(( EXT_OFFS + ROOTFS_SIZE + ROOTFS_DATA_SIZE + 2 * PART_SIZE ))
else
	# Calculate total image size
	IMAGE_SIZE=$(( FS_OFFSET + BOOT_SIZE ))
fi

check_format() {
	return 1
}

# Append partition image to disk image
append_image() {
	/usr/bin/dd if="${2}" of="${TARGET}" bs=512 seek="${1}" conv=notrunc status=none
}

# Create ext4 partition
create_ext4_partition() {
	echo "[Creating \"${2}\" partition...]"

	EXT4_PART="${WORKDIR_TMP}/${2}.part"

	# Format ext4 partition image
	/usr/sbin/mkfs.ext4 -q -F -m 1 -L "${2}" \
		-E root_owner=0:0,lazy_itable_init=0,lazy_journal_init=0 \
		-O encrypt,ext_attr "${EXT4_PART}" "${3}M" > /dev/null

	# Add ext4 partition to disk image
	append_image "${1}" "${EXT4_PART}"

	# Remove ext4 partition image
	rm -f "${EXT4_PART}"
}

# Create boot partition
create_boot_partition() {
	echo "[Creating \"boot\" partition...]"

	BOOT_PART="${WORKDIR_TMP}/boot.part"

	# Format boot partition
	/usr/sbin/mkfs.vfat -F 32 -n BOOT -C "${BOOT_PART}" $(( BOOT_SIZE * 1024 )) > /dev/null

	# Copy files to boot partition
	if [ -f "${SRCDIR}/tispl.bin" ]; then
		/usr/bin/mcopy -i "${BOOT_PART}" \
			"${SRCDIR}/tispl.bin" \
			"${SRCDIR}/tiboot3.bin" \
			"${SRCDIR}/u-boot.img" \
			"${SRCDIR}/uboot.env" \
			::/
	elif [ -f "${SRCDIR}/flash.bin" ]; then
		/usr/bin/mcopy -i "${BOOT_PART}" "${SRCDIR}/uboot.env" ::/
		append_image 64 "${SRCDIR}/flash.bin"
	else
		${SECURE} && EXT="cip" || EXT="bin"
		/usr/bin/mcopy -i "${BOOT_PART}" \
			"${SRCDIR}/boot.${EXT}" \
			"${SRCDIR}/u-boot.itb" \
			"${SRCDIR}/uboot.env" \
			::/
	fi

	if ! ${boot_only}; then
		/usr/bin/mcopy -i "${BOOT_PART}" "${SRCDIR}/kernel.itb" ::/
	fi

	# Add boot partition to disk image
	append_image "${1}" "${BOOT_PART}"

	# Remove boot partition image
	rm -f "${BOOT_PART}"
}

# Create swap partition
create_swap_partition() {
	echo "[Creating \"swap\" partition...]"

	SWAP_PART="${WORKDIR_TMP}/swap.part"

	# Create swap partition image
	/usr/bin/fallocate -l "${SWAP_SIZE}MiB" "${SWAP_PART}"
	chmod 600 "${SWAP_PART}"

	# Format swap partition image
	/usr/sbin/mkswap -L swap "${SWAP_PART}" > /dev/null

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

TARGET_FINAL=${TARGET}
TARGET="${WORKDIR_TMP}/image"

echo "[Creating SD card image...]"

if ! check_format ; then
	# Create disk image
	/usr/bin/fallocate -l ${IMAGE_SIZE}M "${TARGET}"

	# Create image partition table
	if ${boot_only}; then
		printf '%s,%sM,0xc,*\n' "${FS_OFFSET}" "${BOOT_SIZE}" | \
			/usr/sbin/sfdisk -q "${TARGET}"
	else
		printf '%sM,%sM,0xc,*\n,%sM,S\n,%sM,L\n%sM,-,Ex\n,%sM,L\n,%s,L\n' \
			"${FS_OFFSET}" "${BOOT_SIZE}" "${SWAP_SIZE}" "${PERM_SIZE}" \
			"${EXT_OFFS}" "${ROOTFS_SIZE}" '-' |\
			/usr/sbin/sfdisk -q "${TARGET}"
	fi
fi

# Read partition table and create partitions
/usr/sbin/sfdisk -qlo device,start "${TARGET}" > "${WORKDIR_TMP}/partitions"
while read -r DEVICE START; do
	num=${DEVICE#"${TARGET}"}
	num=${num#p}
	case ${num} in
		1) create_boot_partition "${START}" & ;;
		2) create_swap_partition "${START}" & ;;
		3) create_ext4_partition "${START}" "perm" "${PERM_SIZE}" & ;;
		5) create_rootfs_partition "${START}" & ;;
		6) create_ext4_partition "${START}" "rootfs_data_a" "${ROOTFS_DATA_SIZE}" & ;;
	esac
done < "${WORKDIR_TMP}/partitions"
rm -f "${WORKDIR_TMP}/partitions"

echo "[Waiting for writes to complete ...]"
wait

# Create sparse image
/usr/bin/fallocate -d "${TARGET}"

# Create bmap file
if command -v bmaptool > /dev/null; then
	echo "[Creating bmap file...]"
	bmaptool create -o "${TARGET_FINAL}.bmap" "${TARGET}"
fi

echo "[Compressing SD card image...]"
xz -9cqT 0 "${TARGET}" > "${TARGET_FINAL}.xz"

echo "[Image file: ${TARGET}.xz]"
echo "SD Card Programming, example using dd or bmaptool:"
echo "  umount /dev/sdX? ; xz -dc ${TARGET_FINAL}.xz | sudo dd of=/dev/sdX bs=4M conv=fsync"
if [ -f "${TARGET_FINAL}.bmap" ]; then
	echo "  umount /dev/sdX? ; sudo bmaptool copy ${TARGET_FINAL}.xz /dev/sdX"
fi

# Flush file system buffers
sync

echo "[Done]"
