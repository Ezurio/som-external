#!/bin/sh

set -e

DRIVE=${1}
ARG=${1##*/}
SRCDIR=${0%/*}
DRIVE_SIZE=/sys/block/${DRIVE##*/}/size

if [ -z "${DRIVE}" ] || [ -z "${ARG}" ]; then
    echo "mksdcard.sh <device>"
    echo "  <device> is the SD card to be programmed (e.g., /dev/sdc)"
    exit
fi

if [ ! -b ${DRIVE} ]; then
    echo "Can not find destination drive \"${DRIVE}\""
    exit
fi

DRIVE_BLOCKS=$(cat ${DRIVE_SIZE})

if [ "${DRIVE_BLOCKS}" -eq 0 ]; then
    echo "Can not find destination drive \"${DRIVE}\""
    exit
fi

if [ ! -e ${SRCDIR}/rootfs.tar ]; then
    echo "Can not find required rootfs.tar file."
    exit
fi

case "${ARG}" in
    sd*)
        PART_BOOT=${DRIVE}1
        PART_SWAP=${DRIVE}2
        PART_ROOTFS=${DRIVE}3
        ;;

    mmcblk*)
        PART_BOOT=${DRIVE}p1
        PART_SWAP=${DRIVE}p2
        PART_ROOTFS=${DRIVE}p3
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

# Un-mount all mounted partitions
unmount_all ${DRIVE}

# Check if device is busy
hdparm -z ${DRIVE} >/dev/null

echo "[Partitioning ${DRIVE}...]"

# Wipe MBR, GPT, and Partition Table
dd if=/dev/zero of=${DRIVE} bs=512 count=34 status=none
dd if=/dev/zero of=${DRIVE} bs=512 count=34 seek=$((DRIVE_BLOCKS-34)) status=none
dd if=/dev/zero of=${DRIVE} bs=1KiB count=1 seek=1024 status=none
dd if=/dev/zero of=${DRIVE} bs=1KiB count=4 seek=$((49*1024)) status=none
dd if=/dev/zero of=${DRIVE} bs=1KiB count=4 seek=$((305*1024)) status=none

parted -s ${DRIVE} mklabel msdos unit MiB \
    mkpart primary fat16 1 49 set 1 lba on set 1 boot on \
    mkpart primary linux-swap 49 305 \
    mkpart primary ext4 305 100%

[ $? -ne 0 ] && exit

sync
sleep 1

echo "[Making file systems...]"

# Format newly created partitions
mkfs.vfat -F 16 -n BOOT ${PART_BOOT} >/dev/null
mkswap -L swap ${PART_SWAP} >/dev/null
mkfs.ext4 -q -L rootfs ${PART_ROOTFS} -E lazy_itable_init=0,lazy_journal_init=0
sync

echo "[Copying files...]"

MNT_BOOT=/mnt/${PART_BOOT##*/}
MNT_ROOTFS=/mnt/${PART_ROOTFS##*/}

# Copy files to boot partition
mkdir -p ${MNT_BOOT}
mount ${PART_BOOT} ${MNT_BOOT}

cp -t ${MNT_BOOT} ${SRCDIR}/boot.bin ${SRCDIR}/u-boot.itb ${SRCDIR}/kernel.itb ${SRCDIR}/uboot.env
sync

umount -f ${MNT_BOOT} && rm -rf ${MNT_BOOT}

# Copy files to rootfs partition
mkdir -p ${MNT_ROOTFS}
mount -o noatime ${PART_ROOTFS} ${MNT_ROOTFS} || exit

tar xf ${SRCDIR}/rootfs.tar -C ${MNT_ROOTFS}
sync

umount ${MNT_ROOTFS} && rm -rf ${MNT_ROOTFS}

unmount_all ${DRIVE}

echo "[Done]"
