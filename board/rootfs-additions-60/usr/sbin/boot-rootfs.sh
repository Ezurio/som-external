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

nextSide() {
	case "${rootDevActual}" in
	mmcblk*)
		read -r soc_id < /sys/devices/soc0/soc_id
		case "${soc_id}" in
		sama5d3*)
			echo a
			;;
		*)
			mmc extcsd read "${rootDevActual%%p*}" | \
				grep -qm 1 'Boot Partition 2 enabled' && echo b || echo a
			;;
		esac
		;;

	ubi*)
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

	MEM_128MB_IN_KB=131072
	MEM_256MB_IN_KB=262144
	MEM_512MB_IN_KB=524288
	MEM_1GB_IN_KB=1048576
	MEM_2GB_IN_KB=2097152
	MEM_4GB_IN_KB=4194304

	read -r soc_id < /sys/devices/soc0/soc_id
	case "${soc_id}" in
	sama5d31*)
		# WB50
		echo "$WB50_BASE_HW_PART_NUMBER"
		;;

	sama5d36*)
		# SOM60
		ram_size=$(sed -rn 's/MemTotal:\s+([0-9]+).*/\1/p' /proc/meminfo)

		if [ "${ram_size}" -le $MEM_128MB_IN_KB ]; then
			[ -f /sys/bus/nvmem/devices/0-00500/nvmem ] &&
			echo "$SOM60v2x1_BASE_HW_PART_NUMBER" ||
			echo "$SOM60x1_BASE_HW_PART_NUMBER"
		elif [ "${ram_size}" -le $MEM_256MB_IN_KB ]; then
			[ -f /sys/bus/nvmem/devices/0-00500/nvmem ] &&
			echo "$SOM60v2x2_BASE_HW_PART_NUMBER" ||
			echo "$SOM60x2_BASE_HW_PART_NUMBER"
		else
			echo "unknown"
		fi
		;;

	i.MX8MP*)
		# SOM 8M Plus
		ram_size=$(sed -rn 's/MemTotal:\s+([0-9]+).*/\1/p' /proc/meminfo)

		if [ "${ram_size}" -le $MEM_512MB_IN_KB ]; then
			echo "$SOM8MP_512MB_BASE_HW_PART_NUMBER"
		elif [ "${ram_size}" -le $MEM_1GB_IN_KB ]; then
			echo "$SOM8MP_1GB_BASE_HW_PART_NUMBER"
		elif [ "${ram_size}" -le $MEM_2GB_IN_KB ]; then
			echo "$SOM8MP_2GB_BASE_HW_PART_NUMBER"
		elif [ "${ram_size}" -le $MEM_4GB_IN_KB ]; then
			echo "$SOM8MP_4GB_BASE_HW_PART_NUMBER"
		else
			echo "unknown"
		fi
		;;

	*)
		echo "unknown"
		;;
	esac
}
