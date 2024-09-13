#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2022 Ezurio

die() {
	echo "${1}" >&2
	/usr/sbin/reboot -f
}

dief() {
	echo
	die "FIPS Integrity check Failed: ${1}"
}

# shellcheck source=/dev/null
. /usr/sbin/boot-rootfs.sh

if [ "${1}" != "restart" ]; then
	INIT=$(sed -nr 's/.*initlrd=([^ ]+).*/\1/p' /proc/cmdline)

	if [ -n "${INIT}" ]; then
		echo "Launching: ${INIT}"

		if [ "${INIT#*.}" = "sh" ]; then
			# shellcheck source=/dev/null
			. "${INIT}"
		else
			${INIT}
		fi
	fi
fi

echo "Launching: ${0}"

[ ! -f /dev/hwrng ] || chmod 644 /dev/hwrng

[ -f /proc/sys/crypto/fips_enabled ] &&
	read -r FIPS_ENABLED </proc/sys/crypto/fips_enabled

if [ "${FIPS_ENABLED}" = "1" ]; then
	echo "FIPS Integrity check Started"

	case "${rootDevActual:?}" in
		mmcblk*)
			KERNEL=/boot/kernel.itb
			BOOT_MOUNT=true
			mkdir -p /boot
			mount -t "${mountFsType:?}" -o ro "/dev/$(getPart kernel)" /boot 2>/dev/null || \
				dief "Cannot mount /boot: $?"
			;;
		ubi*)
			KERNEL="/dev/$(getPart kernel)"
			BOOT_MOUNT=false
			;;
		*)
			dief "ERROR: unsupported root device: ${rootDevActual}"
			;;
	esac

	mount -o mode=1777,nosuid,nodev,noexec -t tmpfs tmpfs /tmp 2>/dev/null

	[ -f /lib/fipscheck/Image.lzma.hmac ] && IMGTYP=lzma || IMGTYP=gz

	/usr/sbin/dumpimage -T flat_dt -p 0 -o "/tmp/Image.${IMGTYP}" "${KERNEL}" >/dev/null || \
		dief "Cannot extract kernel image error: $?"

	if [ -f /usr/lib/libcrypto.so.1.0.0 ]; then
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/libcrypto.so.1.0.0 || \
			dief "fipscheck error: $?"
	else
		ossl-fipsload -B
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/ossl-modules/fips.so || \
			dief "fipscheck error: $?"
	fi

	#shred -zufn 0 "/tmp/Image.${IMGTYP}"
	rm -f "/tmp/Image.${IMGTYP}"

	${BOOT_MOUNT} && umount /boot

	# trigger kernel crypto gcm self-test
	modprobe tcrypt mode=35 || die "Boot gcm(aes) test failed: $?"
	modprobe -r tcrypt

	echo "FIPS Integrity check Success"
fi

exec /usr/sbin/init
