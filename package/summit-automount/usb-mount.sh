#!/bin/sh
# Copyright (c) 2018-2024, Ezurio
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#                               
# This script is called from our systemd unit file to mount or unmount
# a USB drive.

set -x

usage()
{
    echo "Usage: $0 <add|remove> <device_name> [mount_user]" >&2
    exit 1
}

parse_blkid()
{
    echo "${1}" | sed -n "s/.*${2}=\"\([^\"]*\).*/\1/p"
}

if [ $# -lt 2 ]; then
    usage
fi

# This allows set default parameters (used for setting user name)
# shellcheck source=/dev/null
test -r /etc/default/usb-mount && . /etc/default/usb-mount

ACTION=${1}
DEVICE=${2}

DEVBASE=${DEVICE#/dev/*}
MOUNT_ROOT="$(readlink -f /media)"

case ${DEVBASE} in
	mmc*) MOUNT_USER=${3:-${MOUNT_USER_MMC}} ;;
	*) MOUNT_USER=${3:-${MOUNT_USER_USB}} ;;
esac

# See if this drive is already mounted, and if so where
MOUNT_POINT="$(awk -v DEV="${DEVICE}" '($1 == DEV) { print $2 }' /proc/mounts)"

MOUNT="/usr/bin/mount"
UMOUNT="/usr/bin/umount"

do_mount()
{
    if [ -z "${DEVBASE%mmc*}" ]; then
       read -r mmctype < "/sys/block/${DEVBASE%p*}/device/type"
       [ "${mmctype}" = "SD" ] || exit 0

       grep -qF "${DEVICE%p*}" /proc/cmdline && exit 0
    fi

    if [ -n "${MOUNT_POINT}" ]; then
        echo "Warning: ${DEVICE} is already mounted at ${MOUNT_POINT}" >&2
        exit 1
    fi

    # Get info for this drive: ID_FS_LABEL and ID_FS_TYPE
    if [ -z "${ID_FS_TYPE}" ]; then
        BLKID=$(/sbin/blkid "${DEVICE}")

        ID_FS_TYPE=$(parse_blkid "${BLKID}" TYPE)
        [ -n "${ID_FS_TYPE}" ] || \
            { echo "${DEVICE} is not a fileystem" >&2; exit 1; }

        ID_FS_LABEL=$(parse_blkid "${BLKID}" LABEL)
        ID_FS_LABEL=$(echo "${ID_FS_LABEL}" | sed -e 's/ /_/g')
    fi

    # Figure out a mount point to use
    if [ -z "${ID_FS_LABEL}" ]; then
        ID_FS_LABEL=${DEVBASE}
    elif grep -q " ${MOUNT_ROOT}/${ID_FS_LABEL} " /proc/mounts; then
        # Already in use, make a unique one
        ID_FS_LABEL="${ID_FS_LABEL}-${DEVBASE}"
    fi
    MOUNT_POINT="${MOUNT_ROOT}/${ID_FS_LABEL}"

    echo "Mount point: ${MOUNT_POINT}" >&2

    mkdir -p "${MOUNT_POINT}"

    # Global mount options
    OPTS="rw,noatime,noexec,nosuid,nodev"

    # File system type specific mount options
    case "${ID_FS_TYPE}" in
    vfat)
        OPTS="${OPTS},flush,users,utf8=1"
        if [ -n "${MOUNT_USER}" ]; then
            OPTS="${OPTS},uid=$(id -u "${MOUNT_USER}"),gid=$(id -g "${MOUNT_USER}")"
        else
            OPTS="${OPTS},gid=$(awk -F':' '/^disk/{print $3}' /etc/group)"
        fi
        ;;
    swap)
        return
        ;;
    esac

    if ! ${MOUNT} -o "${OPTS}" "${DEVICE}" "${MOUNT_POINT}"; then
        echo "Error mounting ${DEVICE} (status = $?)" >&2
        rmdir "${MOUNT_POINT}"
        exit 1
    fi

    # Change ownership of mounted drive to user, if specified
    [ -z "${MOUNT_USER}" ] || chown "${MOUNT_USER}" "${MOUNT_POINT}"

    if [ -n "${MOUNT_USER_EXEC}" ]; then
        if [ -x /usr/bin/systemctl ]; then
            for i in ${MOUNT_USER_EXEC} ; do
                /usr/bin/systemctl --no-block start "$(/usr/bin/systemd-escape -p --template="${i}" "${MOUNT_POINT}")"
            done
        else
            for i in ${MOUNT_USER_EXEC} ; do
                if [ -x "${i}" ]; then
                    nohup "${i}" "${MOUNT_POINT}" &
                fi
            done
        fi
    fi

    echo "**** Mounted ${DEVICE} at ${MOUNT_POINT} ****" >&2
}

do_unmount()
{
    for f in ${MOUNT_POINT} ; do
        case "${f}" in
		"${MOUNT_ROOT}"*)
            ${UMOUNT} -l "${f}" && echo "**** Unmounted ${f} ${DEVICE}" >&2 ;;
        "") echo "Warning: ${DEVICE} is not mounted" >&2 ;;
        *) echo "Warning: ${DEVICE} is not managed by usb-mount" >&2 ;;
        esac
    done

    # Delete all empty dirs in MOUNT_ROOT that aren't being used as mount
    # points. This is kind of overkill, but if the drive was unmounted
    # prior to removal we no longer know its mount point, and we don't
    # want to leave it orphaned...
    for f in "${MOUNT_ROOT}/"* ; do
        if [ -e "${f}" ] && [ -z "$(ls -A "${f}")" ]; then
            if ! grep -qF " ${f} " /proc/mounts; then
                echo "**** Removing mount point ${f}" >&2
                rmdir "${f}"
            fi
        fi
    done
}

case "${ACTION}" in
    add)
        do_mount
        ;;

    remove)
        do_unmount
        ;;

    *)
        usage
        ;;
esac
