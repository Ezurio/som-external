#!/bin/sh
# shellcheck disable=SC2034
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

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

rootDevType() {
    case "${rootDevActual}" in
        mmcblk*)
            read -r rootMMCTypeV < "/sys/block/${rootDevName}/device/type"
            echo "${rootMMCTypeV}"
            ;;
        ubi*)
            echo "ubi"
            ;;
    esac
}

getPart() {
    PART="${1}"

    case "${PART}" in
    rootfs)
        echo "${rootDevPrefix}${rootBlock}"
        return
        ;;

    kernel|rootfs_data)
        SIDE=$(getSide)
        [ -z "${SIDE}" ] || PART="${PART}_${SIDE}"
        ;;
    esac

    case "${rootDevActual}" in
        mmcblk*)
            if [ "$(/usr/bin/lsblk -ndlo PTTYPE "/dev/${rootDevName}" 2>/dev/null)" = gpt ]; then
                /usr/bin/lsblk -nlo PARTLABEL,NAME "/dev/${rootDevName}" | awk "\$1 == \"${PART}\" { print \$2 }"
            else
                case "${PART}" in
                    boot)           echo "${rootDevPrefix}1" ;;
                    swap)           echo "${rootDevPrefix}2" ;;
                    perm)           echo "${rootDevPrefix}3" ;;
                    rootfs_a)       echo "${rootDevPrefix}5" ;;
                    rootfs_data_a)  echo "${rootDevPrefix}6" ;;
                esac
            fi
            ;;

        ubi*)
            for f in /sys/class/ubi/"${rootDevPrefix}"*; do
                read -r ubi_name < "${f}/name"
                if [ "${ubi_name}" = "${PART}" ]; then
                    echo "${f#/sys/class/ubi/}"
                    break
                fi
            done
            ;;
    esac
}

getSide() {
    bootSide=$(sed -rn 's,.*bootside=([ab]).*,\1,p' /proc/cmdline)
    if [ -n "${bootSide}" ]; then
        echo "${bootSide}"
        return
    fi

    case "${rootDevActual}" in
        mmcblk*)
            if [ "$(/usr/bin/lsblk -ndlo PTTYPE "/dev/${rootDevPrefix}${rootBlock}" 2>/dev/null)" = gpt ]; then
                bootside=$(/usr/bin/lsblk -ndlo PARTLABEL "/dev/${rootDevPrefix}${rootBlock}")
                bootside=${bootside##*_}
            else
                bootside=a
            fi
            ;;

        ubi*)
            if [ -f "/sys/class/ubi/${rootDevPrefix}${rootBlock}/name" ]; then
                read -r bootside < "/sys/class/ubi/${rootDevPrefix}${rootBlock}/name"
                bootside=${bootside##*_}
            fi
            ;;
    esac

    case ${bootside} in
        a|b) echo "${bootside}" ;;
    esac
}
