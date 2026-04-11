#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio
#
# Read-write rootfs for Summit SOM using overlayfs

OVERLAY_ROOT=/mnt
ROOT_RO_MOUNT=${OVERLAY_ROOT}/ro
ROOT_RW_MOUNT=${OVERLAY_ROOT}/rw
ROOT_NEW_MOUNT=${OVERLAY_ROOT}/newroot
ROOT_NEW_RO_MOUNT=${ROOT_NEW_MOUNT}/ro
ROOT_NEW_RW_MOUNT=${ROOT_NEW_MOUNT}/rw

[ -d '/sys/module/overlay' ] ||
	/sbin/modprobe -q overlay || die "ERROR: could not load overlay module"

# create a writable fs to then create our mountpoints
/bin/mount -t tmpfs inittemp /mnt ||
	die "ERROR: could not create a temporary filesystem"

mkdir ${ROOT_RO_MOUNT} ${ROOT_RW_MOUNT}
/bin/mount -o noatime -t "${mountFsType:?}" "/dev/$(getPart rootfs_data)" ${ROOT_RW_MOUNT} ||
	die "ERROR: could not create parition for upper filesystem"

/bin/mount -t "$(rootMountType)" -o ro "/dev/${rootDev:?}" ${ROOT_RO_MOUNT} ||
	die "ERROR: could not ro mount original root partition"

mkdir -p ${ROOT_RW_MOUNT}/upper ${ROOT_RW_MOUNT}/work ${ROOT_NEW_MOUNT}
/bin/mount -t overlay -o noatime,lowerdir=${ROOT_RO_MOUNT},upperdir=${ROOT_RW_MOUNT}/upper,workdir=${ROOT_RW_MOUNT}/work \
	overlay-rootfs ${ROOT_NEW_MOUNT} ||
	die "ERROR: could not mount overlayFS"

# remove root mount from fstab
/bin/sed -e '\,/dev/root, s,^,# ,' ${ROOT_RO_MOUNT}/etc/fstab > ${ROOT_NEW_MOUNT}/etc/fstab

# create mount points inside the new rootfs overlay
mkdir -p ${ROOT_NEW_RO_MOUNT} ${ROOT_NEW_RW_MOUNT}
/bin/mount -n --move ${ROOT_RO_MOUNT} ${ROOT_NEW_RO_MOUNT}
/bin/mount -n --move ${ROOT_RW_MOUNT} ${ROOT_NEW_RW_MOUNT}

# change to the new overlay root
cd ${ROOT_NEW_MOUNT} || die "ERROR: could not change to new root"
/sbin/pivot_root . ${OVERLAY_ROOT#/}

exec /usr/sbin/chroot . /bin/sh -c "
for i in dev proc sys run; do
	/bin/mount --move ${OVERLAY_ROOT}/\${i} /\${i}
done

/bin/umount ${OVERLAY_ROOT}${OVERLAY_ROOT}
/bin/umount ${OVERLAY_ROOT}

exec /bin/pre-systemd-init.sh restart
"
