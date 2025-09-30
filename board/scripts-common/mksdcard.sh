#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

SRCDIR=$(dirname "${0}")
ROOTFS_DATA_SIZE=
SECURE=false
ADD_SWU=false

die () {
	echo "$@" >&2
	exit 1
}

usage() {
	echo "mksdcard.sh [-s] [-r <size MiB> ] [-h] <device>" >&2
	echo "  -s: Secure boot" >&2
	echo "  -r: rootfs_data size in MiB" >&2
	echo "  -b: boot size in MiB" >&2
	echo "  -p: perm size in MiB" >&2
	echo "  -w: swap size in MiB" >&2
	echo "  -u: add swu file to rootfs_data" >&2
	echo "  -h: Show this help" >&2
	echo "  <device> is the SD card to be programmed (e.g., /dev/sdc)"
	exit 1
}

check_present() {
	for i in "${@}"; do
		which "${i}" > /dev/null || die "${i} utility not found"
	done
}

while getopts sur:b:p:w:f:h name; do
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
	u)  ADD_SWU=true ;;
	?)  usage ;;
	esac
done
shift $((OPTIND - 1))

TARGET="${1}"

[ -n "${TARGET}" ] || usage

[ -b "${TARGET}" ] ||
	die "Device \"${TARGET}\" not found"

[ "$(cat "/sys/block/${TARGET##*/}/size")" -ne 0 ] ||
	die "Device \"${TARGET}\" not found"

case "${TARGET}" in
	/dev/sd*)
		# Check to avoid formatting local hard drives
		[ "$(cat "/sys/block/${TARGET##*/}/removable")" -eq 1 ] ||
			die "Device is not removable."
		;;
esac

[ "$(id -u)" -eq 0 ] ||
	die "This script must be run as root."

check_present sfdisk lsblk mkfs.ext4 mkfs.vfat mkswap dd mount umount

set -e

# Specify partition sizes in MiB
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

WORKDIR_TMP=$(mktemp -d -t mksdcard.XXXXXX)

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
	maxpart=6
else
	boot_only=true
	maxpart=1
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
		ROOTFS_DATA_SIZE="-"
	else
		ROOTFS_DATA_SIZE=${ROOTFS_DATA_SIZE}M
	fi

	EXT_OFFS=$(( FS_OFFSET + BOOT_SIZE + SWAP_SIZE + PERM_SIZE ))
fi

which /usr/bin/udisksctl > /dev/null && udisk=1 || udisk=0

unmount_all() {
	drives=$(grep -o "^${1}p\?[0-9]*" /proc/mounts) || return 0

	for f in ${drives} ; do
		if [ "${udisk}" -ne 0 ]; then
			/usr/bin/udisksctl unmount -f -b "${f}" >/dev/null
		else
			/usr/bin/umount -f "${f}" >/dev/null
		fi
	done

	sleep 1
}

check_format() {
	temp=${WORKDIR_TMP}/check_format
	/usr/sbin/sfdisk -qlo device,id,size "${TARGET}" > "${temp}" 2> /dev/null \
		|| return 1

	num=0
	while read -r DEVICE TYPE SIZE; do
		num=${DEVICE#"${TARGET}"}
		num=${num#p}
		case "${num}" in
			1) [ "${TYPE}" =  "c" ] && [ "${SIZE}" =   "${BOOT_SIZE}M" ] ;;
			2) [ "${TYPE}" = "82" ] && [ "${SIZE}" =   "${SWAP_SIZE}M" ] ;;
			3) [ "${TYPE}" = "83" ] && [ "${SIZE}" =   "${PERM_SIZE}M" ] ;;
			4) [ "${TYPE}" =  "5" ] ;;
			5) [ "${TYPE}" = "83" ] && [ "${SIZE}" = "${ROOTFS_SIZE}M" ] ;;
			6) [ "${TYPE}" = "83" ] &&
				case "${ROOTFS_DATA_SIZE}" in
					-) [ -z "$(sfdisk -q --list-free "${TARGET}")" ] ;;
					"${SIZE}") ;;
					*) false ;;
				esac
				;;
		esac || num=255 break
	done < "${temp}"

	rm -f "${temp}"
	[ "${num}" -eq "${maxpart}" ] 2> /dev/null
}

# Create ext4 file system image
create_ext4_partition() {
	echo "[Creating \"${2}\" partition...]"

	# Format ext4 partition image
	/usr/sbin/mkfs.ext4 -q -F -m 1 -L "${2}" \
		-E root_owner=0:0,lazy_itable_init=0,lazy_journal_init=0 \
		-O encrypt,ext_attr ${3:+-d "${3}/"} "${1}" > /dev/null
}

# Create boot partition
create_boot_partition() {
	echo "[Creating \"boot\" partition...]"

	# Format boot partition
	/usr/sbin/mkfs.vfat -F 32 -n BOOT "${1}" > /dev/null

	BOOT_PART=${WORKDIR_TMP}/boot_part
	mkdir -p "${BOOT_PART}"
	/usr/bin/mount "${1}" "${BOOT_PART}"

	# Copy files to boot partition
	if [ -f "${SRCDIR}/tispl.bin" ]; then
		cp -t "${BOOT_PART}" \
			"${SRCDIR}/tispl.bin" \
			"${SRCDIR}/tiboot3.bin" \
			"${SRCDIR}/u-boot.img" \
			"${SRCDIR}/uboot.env"
		if [ -f "${SRCDIR}/tiboot3.bin.kw" ]; then
			cp -t "${BOOT_PART}" "${SRCDIR}/tiboot3.bin.kw"
		fi
	elif [ -f "${SRCDIR}/flash.bin" ]; then
		cp -t "${BOOT_PART}" "${SRCDIR}/uboot.env"
		/usr/bin/dd if="${SRCDIR}/flash.bin" of="${TARGET}" bs=1k seek=32 status=none
	else
		${SECURE} && EXT="cip" || EXT="bin"
		cp -t "${BOOT_PART}" \
			"${SRCDIR}/boot.${EXT}" \
			"${SRCDIR}/u-boot.itb" \
			"${SRCDIR}/uboot.env"
	fi

	if ! ${boot_only}; then
		cp -t "${BOOT_PART}" "${SRCDIR}/kernel.itb"
	fi

	sync

	/usr/bin/umount -f "${BOOT_PART}" && rmdir "${BOOT_PART}"
}

# Create swap partition
create_swap_partition() {
	echo "[Creating \"swap\" partition...]"

	/usr/sbin/mkswap -f -L swap "${1}" > /dev/null 2> /dev/null
}

# Create rootfs partition
create_rootfs_partition() {
	echo "[Creating \"rootfs_a\" partition...]"

	# Copy files to rootfs partition
	/usr/bin/dd if="${ROOTFS_PATH}" of="${1}" bs=1M conv=fsync status=none
}

add_swu() {
	[ -n "${SWU_PATH}" ] || SWU_PATH=$(find_file '*.swu')
	if [ -n "${SWU_PATH}" ]; then
		echo "[Adding SWU file to rootfs_data partition...]"
		ROOTFS_DATA_PATH=${WORKDIR_TMP}/rootfs_data
		mkdir -p "${ROOTFS_DATA_PATH}"
		cp "${SWU_PATH}" "${ROOTFS_DATA_PATH}/"
	else
		echo "[No SWU file found, skipping...]"
	fi
}

# Un-mount all mounted partitions
unmount_all "${TARGET}"

echo "[Creating SD card image...]"

if ! check_format ; then
	echo "[Partitioning ${TARGET}...]"

	# Wipe partition table if gpt
	if [ "$(/usr/bin/lsblk -nldo pttype "${TARGET}")" = 'gpt' ]; then
		/usr/sbin/sgdisk -Z "${TARGET}" > /dev/null || \
			die "Failed to wipe 'gpt' partition table"
	fi

	# Create device partition table
	if ${boot_only}; then
		printf '%s,%sM,0xc,*\n' "${FS_OFFSET}" "${BOOT_SIZE}" | \
			/usr/sbin/sfdisk -q -W always "${TARGET}" 2> /dev/null
	else
		printf '%sM,%sM,0xc,*\n,%sM,S\n,%sM,L\n%sM,-,Ex\n,%sM,L\n,%s,L\n' \
			"${FS_OFFSET}" "${BOOT_SIZE}" "${SWAP_SIZE}" "${PERM_SIZE}" \
			"${EXT_OFFS}" "${ROOTFS_SIZE}" "${ROOTFS_DATA_SIZE}" | \
			/usr/sbin/sfdisk -q -W always "${TARGET}" 2> /dev/null
	fi

	sync
else
	echo "[Reusing existing partitioning ...]"
fi

! ${ADD_SWU} || add_swu

# Read partition table and create partitions
/usr/sbin/sfdisk -qlo device "${TARGET}" > "${WORKDIR_TMP}/partitions"
while read -r DEVICE; do
	num=${DEVICE#"${TARGET}"}
	num=${num#p}
	case ${num} in
		1) create_boot_partition "${DEVICE}" & ;;
		2) create_swap_partition "${DEVICE}" & ;;
		3) create_ext4_partition "${DEVICE}" "perm" & ;;
		5) create_rootfs_partition "${DEVICE}" & ;;
		6) create_ext4_partition "${DEVICE}" "rootfs_data_a" "${ROOTFS_DATA_PATH}" & ;;
	esac
done < "${WORKDIR_TMP}/partitions"
rm -f "${WORKDIR_TMP}/partitions"

echo "[Waiting for writes to complete ...]"
wait

# Flush file system buffers
sync

unmount_all "${TARGET}"

echo "[Done]"
