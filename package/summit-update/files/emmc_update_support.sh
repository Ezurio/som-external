#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2025 Ezurio

flash_cleanup() { : ; }
flash_factory_test() { : ; }

flash_format() { 
	getSocId

	for i in /sys/block/mmcblk*/device/type ; do
		read -r type < "${i}"
		[ "${type}" = "MMC" ] || continue

		sysblock=${i%/device/type}
		dev=/dev/${sysblock##*/}

		case ${soc_id:?} in
		AM62*|J722S)
			echo "Provisioning ${dev}"
			eval $(mmc extcsd read "${dev}" | sed -rn 's/.*(BOOT_BUS_CONDITIONS|RST_N_FUNCTION|PARTITION_CONFIG)\]?: ([0-9a-fx]+).*/\1=\2/p')
			[ $((BOOT_BUS_CONDITIONS)) = 2 ] ||
				mmc bootbus set single_backward x1 x8 "${dev}"
			[ $((PARTITION_CONFIG)) = $((0x48)) ] || [ $((PARTITION_CONFIG)) = $((0x50)) ] ||
				mmc bootpart enable 1 1 "${dev}"
			[ $((RST_N_FUNCTION)) = 1 ] ||
				mmc hwreset enable "${dev}"
			;;
		esac

		echo "Erasing ${dev}"
		read -r size < "${sysblock}/size"
		mmc erase secure-erase 0 $((size-1)) "${dev}"

		for b in 0 1; do
			[ -e "${sysblock}boot${b}" ] || continue
			echo "Erasing ${sysblock}boot${b}"
			read -r size < "${sysblock}boot${b}/size"
			mmc erase secure-erase 0 $((size-1)) "${dev}boot${b}"
		done
	done
}
