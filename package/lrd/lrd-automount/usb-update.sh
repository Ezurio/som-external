#!/bin/sh

# usb-update - Perform firmware update from USB
#
# This script checks for the existence of a firmware update
# file on the specified device, and applies the update.
# If successful, data is migrated and the device is rebooted.

DEVICE="${1}"

# Wait for device to finish (e.g, mounting)
udevadm wait ${DEVICE}

# Find mount point from device
MOUNT_POINT="$(awk -v DEV=${DEVICE} '($1 == DEV) { print $2 }' /proc/mounts)"

if [ -z "${MOUNT_POINT}" ]; then
    echo "${DEVICE} not mounted."
    exit 1
fi

# Find first .swu file on device
UPDATE_FILE=$(echo $(ls -1 "${MOUNT_POINT}"/*.swu) | cut -d ' ' -f 1)

if [ -z "${UPDATE_FILE}" ]; then
    echo "No update file found on ${MOUNT_POINT}."
    exit 0
fi

echo "Performing update from ${UPDATE_FILE}"

fw_update "${UPDATE_FILE}"
