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
		AM62X)
			echo "Provisioning ${dev}"
			buscond=$(mmc extcsd read "${dev}" |
				sed -rn 's/.*BOOT_BUS_CONDITIONS: ([0-9a-fx]+).*/\1/p')
			[ "${buscond}" = "0x02" ] ||
				mmc bootbus set single_backward x1 x8 "${dev}"
			hwreset=$(mmc extcsd read "${dev}" |
				sed -rn 's/.*\[RST_N_FUNCTION\]: ([0-9a-fx]+).*/\1/p')
			[ "${hwreset}" = "0x01" ] ||
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
