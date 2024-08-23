#!/bin/sh

die() {
	printf "\nFIPS Integrity check Failed: %s\n" "${1}" >&2
	/usr/sbin/reboot -f
}

[ ! -f /dev/hwrng ] || chmod 644 /dev/hwrng

mount -t proc -o rw,nosuid,nodev,noexec proc /proc ||
	die "ERROR: could not mount /proc"

[ -f /proc/sys/crypto/fips_enabled ] &&
	read -r FIPS_ENABLED </proc/sys/crypto/fips_enabled

if [ "${FIPS_ENABLED}" = "1" ]; then
	echo "FIPS Integrity check Started"

	# shellcheck source=/dev/null
	. /usr/sbin/boot-rootfs.sh || fail

	case "${rootDevActual:?}" in
		mmcblk*)
			KERNEL=/boot/kernel.itb
			BOOT_MOUNT=true
			mkdir -p /boot
			mount -t "${mountFsType:?}" -o ro "/dev/$(getPart kernel)" /boot 2>/dev/null || \
				die "Cannot mount /boot: $?"
			;;
		ubi*)
			KERNEL="/dev/$(getPart kernel)"
			BOOT_MOUNT=false
			;;
		*)
			die "ERROR: unsupported root device: ${rootDevActual}"
			;;
	esac

	mount -o mode=1777,nosuid,nodev,noexec -t tmpfs tmpfs /tmp 2>/dev/null

	[ -f /lib/fipscheck/Image.lzma.hmac ] && IMGTYP=lzma || IMGTYP=gz

	/usr/sbin/dumpimage -T flat_dt -p 0 -o "/tmp/Image.${IMGTYP}" "${KERNEL}" >/dev/null || \
		die "Cannot extract kernel image error: $?"

	if [ -f /usr/lib/libcrypto.so.1.0.0 ]; then
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/libcrypto.so.1.0.0 || \
			die "fipscheck error: $?"
	else
		ossl-fipsload -B
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/ossl-modules/fips.so || \
			die "fipscheck error: $?"
	fi

	#shred -zufn 0 "/tmp/Image.${IMGTYP}"
	rm -f "/tmp/Image.${IMGTYP}"

	${BOOT_MOUNT} && umount /boot

	# trigger kernel crypto gcm self-test
	modprobe tcrypt mode=35 || die "Boot gcm(aes) test failed: $?"
	modprobe -r tcrypt

	echo "FIPS Integrity check Success"
fi

INIT=$(sed -nr 's/.*initlrd=([^ ]+).*/\1/p' /proc/cmdline)

[ -n "${INIT}" ] || INIT=/usr/sbin/init

echo "Launching: ${INIT}"

if [ "${INIT#*.}" = "sh" ]; then
	# shellcheck source=/dev/null
	. "${INIT}"
else
	exec ${INIT}
fi
