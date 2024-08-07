#!/bin/sh
# Read-write rootfs for Summit SOM using overlayfs

OVERLAY_ROOT=/mnt
ROOT_RO_MOUNT=${OVERLAY_ROOT}/ro
ROOT_RW_MOUNT=${OVERLAY_ROOT}/rw
ROOT_NEW_MOUNT=${OVERLAY_ROOT}/newroot
ROOT_NEW_RO_MOUNT=${ROOT_NEW_MOUNT}/ro
ROOT_NEW_RW_MOUNT=${ROOT_NEW_MOUNT}/rw

fail() {
    echo "${1}" ; /bin/sh
}

. /usr/sbin/boot-rootfs.sh || fail

# create a writable fs to then create our mountpoints
mount -t tmpfs inittemp /mnt ||
    fail "ERROR: could not create a temporary filesystem"

mkdir ${ROOT_RO_MOUNT} ${ROOT_RW_MOUNT}
mount -o noatime -t "${rootFsType}" "/dev/${rootDevPrefix}$((rootBlock + 1))" ${ROOT_RW_MOUNT} ||
    fail "ERROR: could not create parition for upper filesystem"

mount -t "${rootFsType}" -o ro "/dev/${rootDev}" ${ROOT_RO_MOUNT} ||
    fail "ERROR: could not ro mount original root partition"

mkdir -p ${ROOT_RW_MOUNT}/upper ${ROOT_RW_MOUNT}/work ${ROOT_NEW_MOUNT}
mount -t overlay -o noatime,lowerdir=${ROOT_RO_MOUNT},upperdir=${ROOT_RW_MOUNT}/upper,workdir=${ROOT_RW_MOUNT}/work \
    overlay-rootfs ${ROOT_NEW_MOUNT} ||
    fail "ERROR: could not mount overlayFS"

# remove root mount from fstab
sed -e '\,/dev/root, s,^,# ,' ${ROOT_RO_MOUNT}/etc/fstab > ${ROOT_NEW_MOUNT}/etc/fstab

# create mount points inside the new rootfs overlay
mkdir -p ${ROOT_NEW_RO_MOUNT} ${ROOT_NEW_RW_MOUNT}
mount -n --move ${ROOT_RO_MOUNT} ${ROOT_NEW_RO_MOUNT}
mount -n --move ${ROOT_RW_MOUNT} ${ROOT_NEW_RW_MOUNT}

# change to the new overlay root
cd ${ROOT_NEW_MOUNT} || fail "ERROR: could not change to new root"
pivot_root . ${OVERLAY_ROOT#/}

exec chroot . /bin/sh -c "
# Move read-only and read-write root file system into the overlay file system
mount --move ${OVERLAY_ROOT}/proc /proc
mount --move ${OVERLAY_ROOT}/sys /sys
mount --move ${OVERLAY_ROOT}/dev /dev

# unmount old read-only root
umount /mnt/mnt
umount /mnt

# continue with regular init
exec /sbin/init
"
