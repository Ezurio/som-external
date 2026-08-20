#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -e

BOOT_MOUNT=/boot

die () {
	echo "$@" >&2
	exit 1
}

case "${1}" in
start)
	# shellcheck source=/dev/null
	. /usr/sbin/boot-rootfs.sh

	case "${rootDevType:?}" in
	SD|MMC)
		BOOT_DEVICE=/dev/$(getPart kernel)

		/bin/mount -o noatime,noexec,nosuid,nodev -t auto \
			"${BOOT_DEVICE}" ${BOOT_MOUNT} || \
			die "Mounting ${DATA_DEVICE} to ${DATA_MOUNT} Failed"
		;;
	esac
	;;

stop)
	[ ! -d ${BOOT_MOUNT} ] || \
		/bin/umount ${BOOT_MOUNT}
	;;

*)
	echo "Usage: ${0} <start|stop>"
	exit 1
	;;
esac
