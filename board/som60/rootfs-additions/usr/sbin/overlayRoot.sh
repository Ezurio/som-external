#!/bin/sh
#  Read-only Root-FS for SOM60 using overlayfs
#  Version 1.0
#
#  Created 2017 by Pascal Suter @ DALCO AG, Switzerland to work on Raspian as custom init script
#  (raspbian does not use an initramfs on boot)
#  Modified by Boris Krasnovskiy to work with Ezurio SOM60
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see
#    <http://www.gnu.org/licenses/>.
#
#
#  Tested with Raspbian mini, 2017-01-11
#
#  This script will mount the root filesystem read-only and overlay it with a temporary tempfs
#  which is read-write mounted. This is done using the overlayFS which is part of the linux kernel
#  since version 3.18.
#  when this script is in use, all changes made to anywhere in the root filesystem mount will be lost
#  upon reboot of the system. The SD card will only be accessed as read-only drive, which significantly
#  helps to prolong its life and prevent filesystem coruption in environments where the system is usually
#  not shut down properly
#
#  Install:
#  copy this script to /sbin/overlayRoot.sh and add "init=/sbin/overlayRoot.sh" to the cmdline.txt
#  file in the raspbian image's boot partition.
#  I strongly recommend to disable swapping before using this. it will work with swap but that just does
#  not make sens as the swap file will be stored in the tempfs which again resides in the ram.
#  run these commands on the booted raspberry pi BEFORE you set the init=/sbin/overlayRoot.sh boot option:
#  sudo dphys-swapfile swapoff
#  sudo dphys-swapfile uninstall
#  sudo update-rc.d dphys-swapfile remove
#
#  To install software, run upgrades and do other changes to the raspberry setup, simply remove the init=
#  entry from the cmdline.txt file and reboot, make the changes, add the init= entry and reboot once more.

fail() {
    echo -e "$1"
    /bin/sh
}

# load module
modprobe overlay ||
    fail "ERROR: missing overlay kernel module"

# mount /proc
mount -t proc proc /proc ||
    fail "ERROR: could not mount proc"

# create a writable fs to then create our mountpoints
mount -t tmpfs inittemp /mnt ||
    fail "ERROR: could not create a temporary filesystem to mount the base filesystems for overlayfs"

mkdir /mnt/lower
mkdir /mnt/rw

# Find our running ubiblock
read -r cmdline </proc/cmdline
for x in ${cmdline}; do
    case "$x" in
    ubi.block=*)
        BLOCK=${x#*,}
        ;;
    esac
done

OVERLAY=$((BLOCK + 1))

mount -o noatime -t ubifs ubi0_$OVERLAY /mnt/rw ||
    fail "ERROR: could not create tempfs for upper filesystem"

mkdir -p /mnt/rw/upper
mkdir -p /mnt/rw/work
mkdir /mnt/newroot

# mount root filesystem readonly
set -- $(mount | awk '$3 == "/" {print $1, $5}')
rootDev=$1
rootFsType=$2

mount -t $rootFsType -o noatime,ro $rootDev /mnt/lower ||
    fail "ERROR: could not ro-mount original root partition"

mount -t overlay -o noatime,lowerdir=/mnt/lower,upperdir=/mnt/rw/upper,workdir=/mnt/rw/work overlayfs-root /mnt/newroot ||
    fail "ERROR: could not mount overlayFS"

# create mountpoints inside the new root filesystem-overlay
mkdir -p /mnt/newroot/ro
mkdir -p /mnt/newroot/rw

# remove root mount from fstab (this is already a non-permanent modification)
grep -v /dev/root /mnt/lower/etc/fstab >/mnt/newroot/etc/fstab &&
    echo "#the original root mount has been removed by overlayRoot.sh\n" \
        "#this is only a temporary modification, the original fstab\n" \
        "#stored on the disk can be found in /ro/etc/fstab\n" \
        >>/mnt/newroot/etc/fstab

# change to the new overlay root
cd /mnt/newroot
pivot_root . mnt

exec chroot . sh -c "$(
    cat <<END
# move ro and rw mounts to the new root
mount --move /mnt/mnt/lower/ /ro ||
    ( echo "ERROR: could not move ro-root into newroot" ; /bin/sh )

mount --move /mnt/mnt/rw /rw ||
    ( echo "ERROR: could not move tempfs rw mount into newroot" ; /bin/sh )

# unmount unneeded mounts so we can unmout the old readonly root
umount /mnt/mnt
umount /mnt/proc
umount /mnt/dev
umount /mnt

# continue with regular init
exec /usr/sbin/init
END
)"
