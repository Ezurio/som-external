#!/bin/sh

fail() {
    echo "$@" >&2
    return 1
}

grep -qF /proc /proc/mounts 2> /dev/null ||
mount -t proc -o rw,nosuid,nodev,noexec proc /proc ||
    fail "ERROR: could not mount /proc"

grep -qF /sys /proc/mounts ||
mount -t sysfs -o rw,nosuid,nodev,noexec sysfs /sys ||
    fail "ERROR: could not mount /sys"

rootDev=$(sed -rn 's,.*root=/dev/([^ ]+).*,\1,p' /proc/cmdline)
case "${rootDev}" in
    dm-*)
        rootDevActual=$(ls "/sys/class/block/${rootDev}/slaves")
        ;;
    *)
        rootDevActual="${rootDev}"
        ;;
esac

case "${rootDevActual}" in
    mmcblk*)
        rootBlock=${rootDevActual##*p}
        rootDevName=${rootDevActual%%p*}
        rootDevPrefix=${rootDevName}p
        rootFsType=auto
        ;;
    ubi*)
        rootBlock=${rootDevActual##*_}
        rootDevName=${rootDevActual%%_*}
        [ "${rootDevName}" = "${rootDevName#ubiblock}" ] ||
            rootDevName=ubi${rootDevName#ubiblock}
        rootDevPrefix=${rootDevName}_
        rootFsType=ubifs
        ;;
    *)
        fail "ERROR: unsupported root device: ${rootDevActual}"
        ;;
esac
