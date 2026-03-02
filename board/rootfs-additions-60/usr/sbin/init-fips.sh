#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2022 Ezurio

dief() {
	echo
	die "FIPS Integrity check Failed: ${1}"
}

echo "Launching: ${0}"

echo "FIPS Integrity check Started"

case "${rootDevType:?}" in
	SD|MMC)
		KERNEL=/boot/kernel.itb
		BOOT_MOUNT=true
		mkdir -p /boot
		/usr/bin/mount -t "${mountFsType:?}" -o ro "/dev/$(getPart kernel)" /boot 2>/dev/null || \
			dief "Cannot mount /boot: $?"
		;;
	ubi)
		KERNEL="/dev/$(getPart kernel)"
		BOOT_MOUNT=false
		;;
esac

IMGTYP=$(basename /lib/fipscheck/Image.*.hmac | sed 's/.*\.\([^.]*\)\.hmac$/\1/')

/usr/sbin/dumpimage -T flat_dt -p 0 -o "/run/Image.${IMGTYP}" "${KERNEL}" >/dev/null || \
	dief "Cannot extract kernel image error: $?"

/usr/bin/ossl-fipsload -B
FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/run/Image.${IMGTYP}" /usr/lib/ossl-modules/fips.so || \
	dief "fipscheck error: $?"

#shred -zufn 0 "/run/Image.${IMGTYP}"
rm -f "/run/Image.${IMGTYP}"

${BOOT_MOUNT} && /usr/bin/umount /boot

# trigger kernel crypto gcm self-test
/sbin/modprobe tcrypt mode=35 || die "Boot gcm(aes) test failed: $?"
/sbin/modprobe -r tcrypt

echo "FIPS Integrity check Success"
