#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -e

DATA_MOUNT=/data

case "${1}" in
start)
	# shellcheck source=/dev/null
	. /usr/sbin/boot-rootfs.sh

	/usr/bin/mount -o noatime,nodev,noexec -t "${mountFsType:?}" \
		"/dev/$(getPart rootfs_data)" "${DATA_MOUNT}"

	# Create encrypted data directory
	DATA_SECRET=${DATA_MOUNT}/secret
	mkdir -p ${DATA_SECRET}

	FSCRYPT_KEY=ffffffffffffffff

	/usr/bin/keyctl search %:_builtin_fs_keys logon fscrypt:${FSCRYPT_KEY} @us || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }

	/usr/bin/fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET} >/dev/null || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }

	/usr/sbin/do_factory_reset.sh check

	echo "Secure Boot Cycle Complete" >/dev/console
	;;

stop)
	/usr/bin/umount ${DATA_MOUNT}
	echo 3 >/proc/sys/vm/drop_caches
	;;

*)
	echo "Usage: ${0} <start/stop>"
	exit 1
	;;
esac
