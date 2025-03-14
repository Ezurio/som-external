#!/bin/sh

flash_cleanup() { : ; }
flash_factory_test() { : ; }

flash_format() { 
	for i in /sys/block/mmcblk*/device/type ; do
		read -r type < "${i}"
		[ "${type}" = "MMC" ] || continue

		echo "Erasing ${i}"

		sysblock=${i%/device/type}
		dev=${sysblock##*/}

		echo "Erasing ${dev}"
		read -r size < "${sysblock}/size"
		mmc erase secure-erase 0 $((size-1)) "/dev/${dev}"

		for b in 0 1; do
			[ -e "${sysblock}boot${b}" ] || continue
			echo "Erasing ${sysblock}boot${b}"
			read -r size < "${sysblock}boot${b}/size"
			mmc erase secure-erase 0 $((size-1)) "/dev/${dev}boot${b}"
		done
	done
}
