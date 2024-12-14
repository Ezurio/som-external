#! /bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -e

case "${1}" in
start)
	# shellcheck source=/dev/null
	. /usr/sbin/boot-rootfs.sh

	case "${rootDevType:?}" in
	MMC)
		getSide
		fwenv=emmc-${bootside:?}
		;;
	SD)
		fwenv=sd
		;;
	ubi)
		fwenv=flash
		;;
	esac
	mount --bind "/etc/fw_env_${fwenv}.config" /etc/fw_env.config
	;;
stop)
	umount /etc/fw_env.config
	;;

*)
	echo "Usage: ${0} <start|stop>"
	exit 1
	;;
esac


