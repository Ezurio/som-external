#!/bin/sh

#
# ggv2_mount_sdcard.sh
#
# Mount a uSD card for use with AWS IoT Greengrass V2
#

SD_DISK=mmcblk0
SD_DISK_DEV=/dev/${SD_DISK}
SD_PART_DEV=${SD_DISK_DEV}p1
SD_PART_MOUNT=/run/media/${SD_DISK}p1
SD_DEV_MAPPER_NAME=sdcard
SD_DEV_MAPPER_PART=/dev/mapper/${SD_DEV_MAPPER_NAME}
DATA_SECRET_DIR=/data/secret
DM_CRYPT_KEY_FILE=${DATA_SECRET_DIR}/dmcrypt.key
SWAPFILE=${SD_PART_MOUNT}/swapfile

mount_sd() {
    [ -f ${DM_CRYPT_KEY_FILE} ] || return 1
    [ -b ${SD_PART_DEV} ] || return 1

    # Decrypt and open the partition
    if ! cryptsetup luksOpen ${SD_PART_DEV} ${SD_DEV_MAPPER_NAME} --key-file ${DM_CRYPT_KEY_FILE} ; then
        echo "Error: unable to setup SD card encryption at ${SD_PART_DEV}" >&2
        return 1
    fi

    # Ensure the mount point exists
    mkdir -p ${SD_PART_MOUNT}

    # Mount the encrypted partition and verify it was mounted
    if ! mount -o noatime ${SD_DEV_MAPPER_PART} ${SD_PART_MOUNT} ; then
        umount_sd
        echo "Error: unable to mount SD card at ${SD_PART_MOUNT}" >&2
        return 1
    fi

    if [ ! -f ${SWAPFILE} ]; then
        # Create 256MB swap file on the SD card
        touch ${SWAPFILE}
        f2fs_io pinfile set ${SWAPFILE}
        f2fs_io fallocate 0 0 $((256 * 1024 * 1024)) ${SWAPFILE}
        chmod 600 ${SWAPFILE}
        if ! mkswap ${SWAPFILE} ; then
            umount_sd
            echo "Error: unable to create swap file ${SWAPFILE}" >&2
            return 1
        fi
    fi
}

umount_sd() {
    if [ -d ${SD_PART_MOUNT} ]; then
        umount ${SD_PART_MOUNT}
        echo 3 >/proc/sys/vm/drop_caches
        rm -rf ${SD_PART_MOUNT}
        cryptsetup luksClose ${SD_DEV_MAPPER_NAME}
    fi

    ${1:-true} || cryptsetup luksErase -q ${SD_PART_DEV}
}

prepare_sd() {
    # Create single primary partition covering device
    echo "Creating partition"
    echo "type=83" | sfdisk -w always ${SD_DISK_DEV}

    # Create key file in secret directory
    dd bs=2048 count=1 if=/dev/random of=${DM_CRYPT_KEY_FILE} iflag=fullblock

    # Format device as dm-crypt
    echo "Formatting drive"
    cryptsetup luksFormat -q -v --use-random --hash sha256 --pbkdf pbkdf2 --type luks2 ${SD_PART_DEV} --key-file ${DM_CRYPT_KEY_FILE}
    sync

    # Open the encrypted partition using key file
    cryptsetup luksOpen ${SD_PART_DEV} ${SD_DEV_MAPPER_NAME} --key-file ${DM_CRYPT_KEY_FILE}

    # Format as F2FS
    echo "Creating filesystem"
    mkfs.f2fs -f ${SD_DEV_MAPPER_PART}
    sync

    cryptsetup luksClose ${SD_DEV_MAPPER_NAME}
}

case "${1}" in
start)
    if ! mount_sd ; then
        prepare_sd
        mount_sd
    fi
    ;;

stop)
    keyctl search @us user factory_reset > /dev/null && NORST=false || NORST=true
    umount_sd ${NORST}
    ;;

prepare)
    prepare_sd
    ;;

*)
    echo "Usage: $0 {start|stop|prepare}"
    exit 1
    ;;
esac
