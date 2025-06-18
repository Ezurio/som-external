#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2025 Ezurio

set -e

RODATA_MOUNT=/rodata
RODATA_IMG=/etc/rodata/rodata.img
DM_CRYPT_KEY_DESC="dm-crypt:ffffffffffffffff"

die() {
	echo "${1}" >&2
	/usr/sbin/dmsetup remove rodata_enc 2> /dev/null
	/usr/bin/umount ${RODATA_MOUNT} 2> /dev/null
	losetup -d "${LOOP_DEVICE}" 2> /dev/null
	exit 1
}

mount_dmcrypt() {
	if mountpoint -q ${RODATA_MOUNT}; then
		echo "Mount point ${RODATA_MOUNT} already exists, skipping mount."
		return 0
	fi

	if [ ! -f "${RODATA_IMG}" ]; then
		die "Encrypted filesystem image not found"
	fi

	losetup -fr ${RODATA_IMG} || {
		die "Failed to find a free loop device for rodata image"
	}

	loop_device_backing_file=$(grep -l "${RODATA_IMG}" /sys/block/loop*/loop/backing_file | head -n 1)
	if [ -z "${loop_device_backing_file}" ]; then
		die "Could not find a loop device associated with ${RODATA_IMG}"
	fi
	loop_device_num="${loop_device_backing_file##*/sys/block/}"
	loop_device_num="${loop_device_num%%/loop/backing_file}"
	LOOP_DEVICE="/dev/${loop_device_num}"
	if [ -z "${LOOP_DEVICE}" ]; then
		die "Could not find a loop device associated with ${RODATA_IMG}"
	fi

	RODATA_SIZE=$(stat -c %b "${RODATA_IMG}")

	 /usr/bin/keyctl search %:_builtin_fs_keys logon ${DM_CRYPT_KEY_DESC} @us > /dev/null || {
		die "Key not found"
	}

	CRYPTO_STR="crypt aes-xts-plain64 :64:logon:${DM_CRYPT_KEY_DESC}"
	/usr/sbin/dmsetup -v create rodata_enc --table "0 ${RODATA_SIZE} \
		${CRYPTO_STR} 0 ${LOOP_DEVICE} 0 1 sector_size:512" || {
		die "Failed to create dm-crypt device"
	}
	
	/usr/bin/mount -t squashfs /dev/mapper/rodata_enc ${RODATA_MOUNT} || {
		/usr/sbin/dmsetup remove rodata_enc
		die "Mounting ${LOOP_DEVICE} to ${RODATA_MOUNT} failed"
	}
}

umount_dmcrypt() {
	/usr/bin/umount ${RODATA_MOUNT}
	/usr/sbin/dmsetup remove rodata_enc
	echo 3 >/proc/sys/vm/drop_caches
}

case "${1}" in
start)
	mount_dmcrypt
	;;

stop)
	unmount_dmcrypt
	;;

*)
	echo "Usage: ${0} <start|stop>"
	exit 1
	;;
esac
