#!/bin/bash

set -e

DRIVE=${1}
ARG=${1##*/}
SRCDIR=${0%/*}

if [ -z "${DRIVE}" -o -z "${ARG}" ]; then
    echo "mksdcard.sh <device>"
    echo "  <device> is the SD card to be programmed (e.g., /dev/sdc)"
    exit
fi

if [ ! -b ${DRIVE} ]; then
    echo "Can not find destination drive \"${DRIVE}\""
    exit
fi

if [ $(id -u) -ne 0 ]; then
    echo "This script must be run as root."
    exit
fi

DRIVE_BLOCKS=$(cat /sys/block/${ARG}/size)

if [ "${DRIVE_BLOCKS}" -eq 0 ]; then
    echo "Can not find destination drive \"${DRIVE}\""
    exit
fi

case "${ARG}" in
    sd*)
        if [ $(cat /sys/block/${ARG}/removable) -ne 1 ]; then
            echo "Device is not removable."
            exit
        fi

        PART_BOOT=${DRIVE}1
        ;;

    mmcblk*)
        PART_BOOT=${DRIVE}p1
        ;;

    *)
        echo "Invalid device name: ${ARG}"
        exit
        ;;
esac

which udisksctl > /dev/null && udisk=1 || udisk=0

unmount_all() {
	local drives="$(grep -o "^${1}p\?[0-9]\+" /proc/mounts)"

	for f in ${drives} ; do
		if [ ${udisk} -ne 0 ]; then
			udisksctl unmount -f -b ${f} >/dev/null
		else
			umount -f ${f} >/dev/null
		fi
	done

	[ -z "${drives}" ] || sleep 1
}

check_format() {
    count=0
    while read -r TYPE FSTYPE SIZE; do
        [ "${TYPE}" = "part" ] || continue
        count=$((count+1))
        case "${count}" in
            1) [ "${FSTYPE}" = "vfat" -a "${SIZE}" = "48M" ] || return ;;
            *) break ;;
        esac
    done < <(lsblk -fln -o TYPE,FSTYPE,SIZE ${DRIVE})
    [ ${count} -eq 1 ]
}

# Un-mount all mounted partitions
unmount_all ${DRIVE}

if ! check_format ; then
    # Check if device is busy
    hdparm -z ${DRIVE} >/dev/null

    echo "[Partitioning ${DRIVE}...]"

    # Wipe MBR, GPT, and Partition Table
    dd if=/dev/zero of=${DRIVE} bs=512 count=34 status=none
    dd if=/dev/zero of=${DRIVE} bs=512 count=34 seek=$((DRIVE_BLOCKS-34)) status=none

    parted -s ${DRIVE} mklabel msdos unit MiB \
        mkpart primary fat16 1 49 set 1 lba on set 1 boot on

    [ $? -ne 0 ] && exit

    sync
    sleep 1
else
    echo "[Reuse existing partitioning ${DRIVE}...]"
fi

echo "[Making file systems...]"

# Format newly created partitions
mkfs.vfat -F 16 -n BOOT ${PART_BOOT} >/dev/null
sync

echo "[Copying files...]"

MNT_BOOT=/mnt/${PART_BOOT##*/}

# Copy files to boot partition
mkdir -p ${MNT_BOOT}
mount ${PART_BOOT} ${MNT_BOOT}

cp -t ${MNT_BOOT} ${SRCDIR}/boot.bin ${SRCDIR}/u-boot.itb ${SRCDIR}/uboot.env
sync

umount -f ${MNT_BOOT} && rm -rf ${MNT_BOOT}

unmount_all ${DRIVE}

echo "[Done]"
