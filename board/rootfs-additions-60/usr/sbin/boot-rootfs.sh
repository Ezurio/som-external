#!/bin/sh
# shellcheck disable=SC2034
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

find_ubi_device() {
	f=$(grep -lxF "${1}" /sys/class/ubi/ubi0_*/name) ||
		die "UBI volume for ${1} not found"

	f=${f#/sys/class/ubi/}
	f=${f%%/name}
	echo "${f}"
}

get_emmc_data() {
	/usr/bin/lsblk -lno NAME,PARTLABEL "/dev/${rootDevActual%%p*}" |\
		sed -rn "${1}"
}

grep -qF /proc /proc/mounts 2> /dev/null ||
mount -t proc -o rw,nosuid,nodev,noexec proc /proc ||
	die "ERROR: could not mount /proc"

grep -qF /sys /proc/mounts ||
mount -t sysfs -o rw,nosuid,nodev,noexec sysfs /sys ||
	die "ERROR: could not mount /sys"

rootMountType() {
	sed -r 's/.*rootfstype=([^ ]+).*/\1/ ;t;s/.*/auto/' /proc/cmdline
}

rootDev=$(sed -rn 's,.*root=/dev/([^ ]+).*,\1,p' /proc/cmdline)
case "${rootDev}" in
	dm-*)
		rootDevActual=$(ls "/sys/class/block/${rootDev}/slaves")
		;;
	*)
		rootDevActual="${rootDev}"
		;;
esac

case "${rootDevActual}" in
	mmcblk*)
		read -r rootDevType < "/sys/block/${rootDevActual%%p*}/device/type"
		mountFsType=auto
		;;

	ubiblock*)
		read -r rootDevName < "/sys/block/${rootDevActual}/device/name"
		rootDevActual=$(find_ubi_device "${rootDevName}")
		rootDevType=ubi
		mountFsType=ubifs
		;;

	ubi*)
		rootDevType=ubi
		mountFsType=ubifs
		;;
	*)
		die "ERROR: unsupported root device: ${rootDevActual}"
		;;
esac

getPart() {
	part="${1}"

	case "${part}" in
	rootfs)
		echo "${rootDevActual}"
		return
		;;

	kernel|rootfs_data)
		# If side is not specified, get it from partition name
		getSide
		[ -z "${bootside}" ] || part="${part}_${bootside}"
		;;
	esac

	case "${rootDevActual}" in
	mmcblk*)
		read -r soc_id < /sys/devices/soc0/soc_id
		case "${soc_id}" in
		sama5d3*)
			case "${part}" in
				boot|kernel_a)  echo "${rootDevActual%%p*}p1" ;;
				swap)           echo "${rootDevActual%%p*}p2" ;;
				perm)           echo "${rootDevActual%%p*}p3" ;;
				rootfs_a)       echo "${rootDevActual%%p*}p5" ;;
				rootfs_data_a)  echo "${rootDevActual%%p*}p6" ;;
			esac
			;;
		*)
			get_emmc_data "s,^([^ ]+) +${part}\$,\1,p"
			;;
		esac
		;;

	ubi*)
		find_ubi_device "${part}"
		;;
	esac
}

getSide() {
	bootside=$(sed -rn 's,.*bootside=([ab]).*,\1,p' /proc/cmdline)
	[ -z "${bootside}" ] || return 0

	case "${rootDevActual}" in
	mmcblk*)
		read -r soc_id < /sys/devices/soc0/soc_id
		case "${soc_id}" in
		sama5d3*)
			bootside=a
			;;
		*)
			bootside=$(get_emmc_data "s,^${rootDevActual%%p*} +(.+),\1,p")
			bootside="${bootside##*_}"
			;;
		esac
		;;

	ubi*)
		read -r bootside < "/sys/class/ubi/${rootDevActual}/name"
		bootside="${bootside##*_}"
		;;
	esac

	[ -n "${bootside}" ] || bootside=a
}
