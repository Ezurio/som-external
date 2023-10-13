#!/bin/sh

# Copyright (c) 2018-2020, Laird Connectivity
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

UDC_DIR=/sys/class/udc
GADGET_DIR=/sys/kernel/config/usb_gadget

counter=0

create_ether() {
	func=functions/${USB_GADGET_ETHER}.usb${counter}

	# Create Ethernet config
	mkdir -p ${func}

	case ${USB_GADGET_ETHER} in
	rndis)
		echo "1" > os_desc/use
		echo "0xcd" > os_desc/b_vendor_code
		echo "MSFT100" > os_desc/qw_sign

		echo "ef" > ${func}/class
		echo "04" > ${func}/subclass
		echo "01" > ${func}/protocol

		echo "RNDIS"   > ${func}/os_desc/interface.rndis/compatible_id
		echo "5162001" > ${func}/os_desc/interface.rndis/sub_compatible_id
		;;

	ncm)
		echo "1" > os_desc/use
		echo "0xcd" > os_desc/b_vendor_code
		echo "MSFT100" > os_desc/qw_sign

		echo "WINNCM" > ${func}/os_desc/interface.ncm/compatible_id
		;;
	esac

	[ -z "${USB_GADGET_ETHER_LOCAL_MAC}" ] || \
		echo "${USB_GADGET_ETHER_LOCAL_MAC}" > ${func}/dev_addr

	[ -z "${USB_GADGET_ETHER_REMOTE_MAC}" ] || \
		echo "${USB_GADGET_ETHER_REMOTE_MAC}" > ${func}/host_addr

	ln -s ${func} configs/c.1

	counter=$((counter+1))
}

create_acm() {
	func=functions/acm.usb${counter}

	mkdir -p ${func}

	ln -s ${func} configs/c.1
	counter=$((counter+1))
}

create_gadgets () {
	test -r /etc/default/usb-gadget && . /etc/default/usb-gadget

	[ ${USB_GADGET_ETHER_PORTS:-0}  -gt 0 ] || \
	[ ${USB_GADGET_SERIAL_PORTS:-0} -gt 0 ] || \
		{ echo "No usb-gadget specified"; exit 1; }

	if [ "$(cat /sys/devices/soc0/soc_id)" = "at91sam9g20" ]; then
		modprobe at91_udc
	else
		modprobe atmel_usba_udc
	fi

	modprobe usb_f_fs

	if [ ! -d "${GADGET_DIR}" ]; then
		mount -t configfs none /sys/kernel/config
		[ -d "${GADGET_DIR}" ] || { echo "ConfigFS not found"; exit 1; }
	fi

	for udc_name in $(ls ${UDC_DIR}); do
		mkdir -p ${GADGET_DIR}/g0
		cd ${GADGET_DIR}/g0

		echo ${USB_GADGET_VENDOR_ID}  > idVendor
		echo ${USB_GADGET_PRODUCT_ID} > idProduct

		mkdir -p strings/0x409
		if [ -e /sys/devices/soc0/soc_uid ]; then
			cat /sys/devices/soc0/soc_uid > strings/0x409/serialnumber
		elif [ -f /sys/class/net/eth0/address ]; then
			sed 's/://g' /sys/class/net/eth0/address > strings/0x409/serialnumber
		else
			echo "deadbeefdeadbeef" > strings/0x409/serialnumber
		fi

		echo "Laird Connectivity" > strings/0x409/manufacturer
		cat /sys/firmware/devicetree/base/model > strings/0x409/product

		mkdir -p configs/c.1/strings/0x409
		echo "USB Composite Configuration" > configs/c.1/strings/0x409/configuration

		port=0
		while [ ${port} -lt ${USB_GADGET_ETHER_PORTS:-0} ]; do
			create_ether
			port=$((port+1))
		done

		port=0
		while [ ${port} -lt ${USB_GADGET_SERIAL_PORTS:-0} ]; do
			create_acm
			port=$((port+1))
		done

		ln -s configs/c.1 os_desc/c.1
		echo ${udc_name} > UDC

		break
	done
}

destroy_gadgets () {
	gadget="${GADGET_DIR}/g0"

	[ -e ${gadget} ] || return

	[ -z "$(cat ${gadget}/UDC)" ] || echo > ${gadget}/UDC

	rm -f ${gadget}/os_desc/c.1

	rm -f ${gadget}/configs/c.1/*.usb*
	rmdir ${gadget}/configs/c.1/strings/0x409
	rmdir ${gadget}/configs/c.1

	rmdir ${gadget}/functions/*.usb*
	rmdir ${gadget}/strings/0x409
	rmdir ${gadget}
}

case "${1}" in
	start)
		create_gadgets
		;;

	stop)
		destroy_gadgets
		;;

	*)
		echo $"Usage: $0 {start|stop}"
		exit 1
esac
