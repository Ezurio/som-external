#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2018 Ezurio

UDC_DIR=/sys/class/udc
GADGET_DIR=/sys/kernel/config/usb_gadget

counter=0

die() {
	echo "${1}" >&2
	exit 1
}

normalize_serial_number() {
	printf '%s' "${1}" | tr '[:upper:]' '[:lower:]' | tr -d ':'
}

get_serial_number_auto() {
	if [ -f /etc/wifi_mac ]; then
		cat /etc/wifi_mac
	elif [ -e /sys/devices/soc0/soc_uid ]; then
		cat /sys/devices/soc0/soc_uid
	elif [ -f /sys/class/net/eth1/address ]; then
		sed 's/://g' /sys/class/net/eth1/address
	elif [ -f /sys/class/net/eth0/address ]; then
		sed 's/://g' /sys/class/net/eth0/address
	else
		echo "deadbeefdeadbeef"
	fi
}

get_serial_number_from_env() {
	serial_number="$(fw_printenv -n "${1}" 2>/dev/null || true)"
	[ -n "${serial_number}" ] || return 1
	normalize_serial_number "${serial_number}"
}

get_serial_number() {
	case "${USB_GADGET_SERIAL_SOURCE:-auto}" in
	uboot_ethaddr)
		get_serial_number_from_env ethaddr || \
			die "USB_GADGET_SERIAL_SOURCE=uboot_ethaddr but ethaddr is not set"
		;;
	uboot_eth1addr)
		get_serial_number_from_env eth1addr || \
			die "USB_GADGET_SERIAL_SOURCE=uboot_eth1addr but eth1addr is not set"
		;;
	custom)
		if [ -n "${USB_GADGET_SERIAL_NUMBER}" ]; then
			printf '%s\n' "${USB_GADGET_SERIAL_NUMBER}"
		else
			die "custom USB_GADGET_SERIAL_SOURCE requires USB_GADGET_SERIAL_NUMBER"
		fi
		;;
	auto)
		get_serial_number_auto
		;;
	*)
		die "Invalid USB_GADGET_SERIAL_SOURCE: ${USB_GADGET_SERIAL_SOURCE}"
		;;
	esac
}

create_ether() {
	func=functions/${USB_GADGET_ETHER}.usb${counter}

	# Create Ethernet config
	mkdir -p "${func}"

	case ${USB_GADGET_ETHER} in
	rndis)
		echo "1" > os_desc/use
		echo "0xcd" > os_desc/b_vendor_code
		echo "MSFT100" > os_desc/qw_sign

		echo "ef" > "${func}/class"
		echo "04" > "${func}/subclass"
		echo "01" > "${func}/protocol"

		echo "RNDIS"   > "${func}/os_desc/interface.rndis/compatible_id"
		echo "5162001" > "${func}/os_desc/interface.rndis/sub_compatible_id"
		;;

	ncm)
		echo "1" > os_desc/use
		echo "0xcd" > os_desc/b_vendor_code
		echo "MSFT100" > os_desc/qw_sign

		echo "WINNCM" > "${func}/os_desc/interface.ncm/compatible_id"
		;;
	esac

	[ -z "${USB_GADGET_ETHER_LOCAL_MAC}" ] || \
		echo "${USB_GADGET_ETHER_LOCAL_MAC}" > "${func}/dev_addr"

	[ -z "${USB_GADGET_ETHER_REMOTE_MAC}" ] || \
		echo "${USB_GADGET_ETHER_REMOTE_MAC}" > "${func}/host_addr"

	ln -s "${func}" configs/c.1

	counter=$((counter+1))
}

create_acm() {
	func=functions/acm.usb${counter}

	mkdir -p ${func}

	ln -s ${func} configs/c.1
	counter=$((counter+1))
}

create_gadget() {
		if [ -d ${GADGET_DIR}/"${1}" ]; then
			return
		fi

		serial_number="$(get_serial_number)" || return 1

		{ mkdir -p ${GADGET_DIR}/"${1}" && cd ${GADGET_DIR}/"${1}"; } || \
			die "Unable to create gadget ${1}"

		echo "${USB_GADGET_VENDOR_ID}"  > idVendor
		echo "${USB_GADGET_PRODUCT_ID}" > idProduct

		mkdir -p strings/0x409
		echo "${serial_number}" > strings/0x409/serialnumber

		echo "Ezurio" > strings/0x409/manufacturer
		read -r model < /sys/firmware/devicetree/base/model
		echo "${model}" > strings/0x409/product

		mkdir -p configs/c.1/strings/0x409
		echo "USB Composite Configuration" > configs/c.1/strings/0x409/configuration

		port=0
		while [ ${port} -lt "${USB_GADGET_ETHER_PORTS:-0}" ]; do
			create_ether
			port=$((port+1))
		done

		port=0
		while [ ${port} -lt "${USB_GADGET_SERIAL_PORTS:-0}" ]; do
			create_acm
			port=$((port+1))
		done

		ln -s configs/c.1 os_desc/c.1
		echo "${1}" > UDC
}

destroy_gadget() {
	gadget="${GADGET_DIR}/${1}"

	[ -e "${gadget}" ] || return

	[ -z "$(cat "${gadget}"/UDC)" ] || echo > "${gadget}"/UDC

	rm -f "${gadget}"/os_desc/c.1

	rm -f "${gadget}"/configs/c.1/*.usb*
	rmdir "${gadget}"/configs/c.1/strings/0x409
	rmdir "${gadget}"/configs/c.1

	rmdir "${gadget}"/functions/*.usb*
	rmdir "${gadget}"/strings/0x409
	rmdir "${gadget}"
}

create_gadgets() {
	# shellcheck source=/dev/null
	[ -r /etc/default/usb-gadget ] && . /etc/default/usb-gadget

	[ "${USB_GADGET_ETHER_PORTS:-0}"  -gt 0 ] || \
	[ "${USB_GADGET_SERIAL_PORTS:-0}" -gt 0 ] || \
		die "No usb-gadget specified"

	if [ -f /sys/devices/soc0/soc_id ]; then
		# Get the SoC ID
		read -r soc_id < /sys/devices/soc0/soc_id
	else
		soc_id="unknown"
	fi

	case "${soc_id}" in
		at91sam9g20)
			modprobe at91_udc
			;;
		at91*|sam*)
			modprobe atmel_usba_udc
			;;
	esac

	modprobe usb_f_fs

	if [ ! -d "${GADGET_DIR}" ]; then
		mount -t configfs none /sys/kernel/config
		[ -d "${GADGET_DIR}" ] || die "ConfigFS not found"
	fi

	if [ -n "${1}" ]; then
		create_gadget "${1}" || return 1
	else
		for udc_name in "${UDC_DIR}"/*; do
			if [ -e "${udc_name}" ]; then
				create_gadget "${udc_name##*/}" || return 1
				break
			fi
		done
	fi
}

destroy_gadgets() {
	if [ -n "${1}" ]; then
		destroy_gadget "${1}"
	else
		for udc_name in "${GADGET_DIR}"/*; do
			if [ -e "${udc_name}" ]; then
				destroy_gadget "${udc_name##*/}"
			fi
		done
	fi
}

case "${1}" in
	start)
		create_gadgets "${2}"
		;;

	stop)
		destroy_gadgets "${2}"
		;;

	restart|reload)
		destroy_gadgets "${2}"
		create_gadgets "${2}"
		;;

	*)
		die "Usage: ${0} <start|stop|restart|reload> [port name]"
esac
