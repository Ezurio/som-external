#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio
# Pre-systemd init script
# This script sets up a writeable partition and mount it to
# /perm before starting systemd; this is necessary because a
# few systemd requirements (logging, and a machine-id file)
# require a writeable filesystem.

set -e

PERM_MOUNT=/perm

# shellcheck source=/dev/null
. /usr/sbin/boot-rootfs.sh

PERM_DEVICE=/dev/$(getPart perm)

# Use custom perm mount options, if present
# shellcheck source=/dev/null
[ ! -r /etc/default/perm-mount-opts ] || . /etc/default/perm-mount-opts
[ -n "${PERM_MOUNT_OPTS}" ] || PERM_MOUNT_OPTS="noatime,nosuid,noexec"

/usr/bin/mount -t "${rootFsType:?}" -o "${PERM_MOUNT_OPTS}" "${PERM_DEVICE}" ${PERM_MOUNT} || {
	echo "Failed to mount ${PERM_DEVICE} on ${PERM_MOUNT}"
	exit 1
}

# Make sure there is at least an empty machine-id file
# (Referenced from symlink on the rootfs)
if [ ! -f "${PERM_MOUNT}/etc/machine-id" ]; then
	mkdir -p "${PERM_MOUNT}/etc"
	touch "${PERM_MOUNT}/etc/machine-id"
fi

mkdir -p ${PERM_MOUNT}/log/journal

# Start init
exec /usr/sbin/init
