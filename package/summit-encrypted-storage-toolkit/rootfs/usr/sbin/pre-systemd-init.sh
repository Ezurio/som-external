#!/bin/sh
# Pre-systemd init script
# This script sets up a writeable partition and mount it to
# /perm before starting systemd; this is necessary because a
# few systemd requirements (logging, and a machine-id file)
# require a writeable filesystem.

PERM_MOUNT=/perm

. /usr/sbin/boot-rootfs.sh

case "${rootDevActual}" in
    mmcblk*)
		read -r soc_id < /sys/devices/soc0/soc_id
		case "${soc_id}" in
			at91*|sam*)
				PERM_DEVICE=/dev/${rootDevPrefix}3
				;;
			*)
				PERM_DEVICE=/dev/${rootDevPrefix}7
				;;
		esac
        ;;
    ubi*)
        PERM_DEVICE=${rootDevPrefix}6
        ;;
    *)
        fail "ERROR: unsupported root device: ${rootDevActual}"
        ;;
esac

# Use custom perm mount options, if present
test -r /etc/default/perm-mount-opts && . /etc/default/perm-mount-opts
test -z "${PERM_MOUNT_OPTS}" && PERM_MOUNT_OPTS="noatime,nosuid,noexec"

/usr/bin/mount -t "${rootFsType}" -o "${PERM_MOUNT_OPTS}" "${PERM_DEVICE}" ${PERM_MOUNT}

# Make sure there is at least an empty machine-id file
# (Referenced from symlink on the rootfs)
if [ ! -f ${PERM_MOUNT}/etc/machine-id ]; then
	mkdir -p ${PERM_MOUNT}/etc
	touch ${PERM_MOUNT}/etc/machine-id
fi

mkdir -p ${PERM_MOUNT}/log/journal

# Start init
exec /usr/sbin/init
