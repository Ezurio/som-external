#!/bin/sh
# shellcheck disable=SC2034
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -o pipefail

find_ubi_device() {
	f=$(grep -lxF "${1}" /sys/class/ubi/ubi0_*/name) ||
		die "UBI volume for ${1} not found"

	f=${f#/sys/class/ubi/}
	f=${f%%/name}
	echo "${f}"
}

find_emmc_device() {
	blkid -l -t PARTLABEL="${1}" -o device -c /dev/null \
	 "/dev/${rootDevActual%%p*}" | sed 's,.*/,,g'
}

find_emmc_part() {
	blkid -s PARTLABEL -o value -c /dev/null "/dev/${rootDevActual}"
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
		if [ -e "/sys/block/${rootDevActual}/device/name" ]; then
			read -r rootDevName < "/sys/block/${rootDevActual}/device/name"
			rootDevActual=$(find_ubi_device "${rootDevName}")
		else
			rootDevActual=ubi${rootDevActual#ubiblock}
		fi

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

getSocId() {
	if [ -f /sys/devices/soc0/soc_id ]; then
		# Get the SoC ID
		read -r soc_id < /sys/devices/soc0/soc_id
	elif [ -f /sys/devices/soc0/family ]; then
		# Get the SoC family
		read -r soc_id < /sys/devices/soc0/family
	else
		soc_id="unknown"
	fi
}

getPart() {
	part="${1}"

	case "${part}" in
	rootfs)
		echo "${rootDevActual}"
		return
		;;

	kernel|rootfs_data)
		getSide
		[ -z "${bootside}" ] || part="${part}_${bootside}"
		;;
	esac

	case "${rootDevType}" in
	SD)
		case "${part}" in
			boot|kernel_a)  echo "${rootDevActual%%p*}p1" ;;
			swap)           echo "${rootDevActual%%p*}p2" ;;
			perm)           echo "${rootDevActual%%p*}p3" ;;
			rootfs_a)       echo "${rootDevActual%%p*}p5" ;;
			rootfs_data_a)  echo "${rootDevActual%%p*}p6" ;;
		esac
		;;
	MMC)
		find_emmc_device "${part}"
		;;

	ubi)
		find_ubi_device "${part}"
		;;
	esac
}

getSide() {
	[ -z "${bootside}" ] || return 0

	bootside=$(sed -rn 's,.*bootside=([ab]).*,\1,p' /proc/cmdline)
	[ -z "${bootside}" ] || return 0

	case "${rootDevType}" in
	SD)
		bootside=a
		;;
	MMC)
		bootside=$(find_emmc_part)
		bootside="${bootside##*_}"
		;;
	ubi)
		read -r bootside < "/sys/class/ubi/${rootDevActual}/name"
		bootside="${bootside##*_}"
		;;
	esac

	[ -n "${bootside}" ] || bootside=a
}

nextSide() {
	case "${rootDevType}" in
	SD)
		echo a
		;;
	MMC)
		mmc extcsd read "${rootDevActual%%p*}" | \
			grep -qm 1 'Boot Partition 2 enabled' && echo b || echo a
		;;
	ubi)
		fw_printenv -n bootside
		;;
	esac
}

getBaseHwPartNumber() {
	WB50_BASE_HW_PART_NUMBER="453-00107"
	SOM60x1_BASE_HW_PART_NUMBER="453-00003"
	SOM60x2_BASE_HW_PART_NUMBER="453-00004"
	SOM60v2x1_BASE_HW_PART_NUMBER="453-00137"
	SOM60v2x2_BASE_HW_PART_NUMBER="453-00138"
	SOM8MP_512MB_BASE_HW_PART_NUMBER="453-00070"
	SOM8MP_1GB_BASE_HW_PART_NUMBER="453-00071"
	SOM8MP_2GB_BASE_HW_PART_NUMBER="453-00072"
	SOM8MP_4GB_BASE_HW_PART_NUMBER="453-00135"

	ram_size=$(free -m | sed -rn 's/^Mem:\s+([0-9]+).*/\1/p')

	getSocId
	case "${soc_id}" in
	sama5d31*)
		# WB50
		echo "${WB50_BASE_HW_PART_NUMBER}"
		;;

	sama5d36*)
		# SOM60
		if [ "${ram_size}" -le 128 ]; then
			[ -f /sys/bus/i2c/devices/0-0050/eeprom ] &&
			echo "${SOM60v2x1_BASE_HW_PART_NUMBER}" ||
			echo "${SOM60x1_BASE_HW_PART_NUMBER}"
		elif [ "${ram_size}" -le 256 ]; then
			[ -f /sys/bus/i2c/devices/0-0050/eeprom ] &&
			echo "${SOM60v2x2_BASE_HW_PART_NUMBER}" ||
			echo "${SOM60x2_BASE_HW_PART_NUMBER}"
		else
			echo "unknown"
		fi
		;;

	i.MX8MP*)
		# SOM 8M Plus
		if [ "${ram_size}" -le 512 ]; then
			echo "${SOM8MP_512MB_BASE_HW_PART_NUMBER}"
		elif [ "${ram_size}" -le 1024 ]; then
			echo "${SOM8MP_1GB_BASE_HW_PART_NUMBER}"
		elif [ "${ram_size}" -le 2048 ]; then
			echo "${SOM8MP_2GB_BASE_HW_PART_NUMBER}"
		elif [ "${ram_size}" -le 4096 ]; then
			echo "${SOM8MP_4GB_BASE_HW_PART_NUMBER}"
		else
			echo "unknown"
		fi
		;;

	AM62X)
		echo "Carbon AM62"
		;;

	AM62LX)
		echo "Carbon AM62L"
		;;

	J722S)
		echo "Carbon AM67"
		;;

	*)
		echo "unknown"
		;;
	esac
}
