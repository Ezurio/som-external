#!/bin/sh

INIT=/usr/sbin/init

fail() {
	printf "\nFIPS Integrity check Failed: %s\n", "${1}" >&2
	/usr/sbin/reboot -f
}

# Mount all filesystems
mount -a 2> /dev/null || true

read -r cmdline </proc/cmdline
for x in ${cmdline}; do
	case "${x}" in
#	ubi.mtd=*)
#		KERNEL=/dev/mtd$((${x#*=} - 2))
#		;;

	initlrd=*)
		INIT=${x#initlrd=}
		;;
	esac
done

fw_printenv -n bootcmd | grep -qFi 0x000e0000 && \
	KERNEL=/dev/mtd4 || KERNEL=/dev/mtd5

if [ -f /dev/hwrng ]; then
	chown root:root /dev/hwrng
	chmod 644 /dev/hwrng
fi

[ -f /proc/sys/crypto/fips_enabled ] &&
	read -r FIPS_ENABLED < /proc/sys/crypto/fips_enabled

if [ "${FIPS_ENABLED}" = "1" ] && [ -n "${KERNEL}" ]; then
	echo "FIPS Integrity check Started"

	[ -f /lib/fipscheck/Image.lzma.hmac ] && IMGTYP=lzma || IMGTYP=gz

	/usr/sbin/dumpimage -T flat_dt -p 0 -o "/tmp/Image.${IMGTYP}" "${KERNEL}" >/dev/null || \
		fail "Cannot extract kernel image error: $?"

	if [ -f /usr/lib/libcrypto.so.1.0.0 ]; then
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/libcrypto.so.1.0.0 || \
			fail "fipscheck error: $?"
	else
		ossl-fipsload -B
		FIPSCHECK_DEBUG=stderr /usr/bin/fipscheck "/tmp/Image.${IMGTYP}" /usr/lib/ossl-modules/fips.so || \
			fail "fipscheck error: $?"
	fi

	#shred -zufn 0 "/tmp/Image.${IMGTYP}"
	rm -f "/tmp/Image.${IMGTYP}"

	# trigger kernel crypto gcm self-test
	modprobe tcrypt mode=35 || fail "Boot gcm(aes) test failed: $?"
	modprobe -r tcrypt

	echo "FIPS Integrity check Success"
fi

echo "Launching: ${INIT}"

if [ "${INIT#*.}" = "sh" ]; then
	# shellcheck source=/dev/null
	. "${INIT}"
else
	exec ${INIT}
fi
