#!/bin/sh

get_macb_interface() {
    ls "${1}"
}

set_mac() {
    # $1 - macb_device
    # $2 - uboot env var
    [ -n "${1}" ] || return

    macb_address="$(fw_printenv -n "${2}")"
    if [ -n "${macb_address}" ]; then
        ip link set "${1}" address "${macb_address}"
    else
        echo "uboot mac address variable ${2} unset"
    fi
}

if [ -n "${INTERFACE}" ]; then
    # running from udev
    case "${DEVPATH}" in
    */f802c000.ethernet/*)
        set_mac "${INTERFACE}" ethaddr
        ;;
    *)
        echo "unrecognized device ${DEVPATH}"
        exit
        ;;
    esac
else
    # running from service
    set_mac "$(get_macb_interface "/sys/devices/platform/ahb/ahb:apb/f802c000.ethernet/net/")" ethaddr
fi
