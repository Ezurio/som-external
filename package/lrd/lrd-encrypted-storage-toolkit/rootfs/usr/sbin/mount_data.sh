#!/bin/sh

set -e

DATA_MOUNT=/data

case $1 in
start)
	# Mount proper data device (based on boot side)
	read -r cmdline </proc/cmdline
	for x in ${cmdline}; do
		case "$x" in
		ubi.block=*)
			BLOCK=${x#*,}
			break
			;;
		esac
	done
	DATA_DEVICE=/dev/ubi0_$((BLOCK + 1))
	/usr/bin/mount -o noatime,noexec,nosuid,nodev -t ubifs ${DATA_DEVICE} ${DATA_MOUNT}

	# Create encrypted data directory
	DATA_SECRET=${DATA_MOUNT}/secret
	mkdir -p ${DATA_SECRET}

	FSCRYPT_KEY=ffffffffffffffff

	keyctl search %:_builtin_fs_keys logon fscrypt:${FSCRYPT_KEY} @us

	fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET} >/dev/null

	. do_factory_reset.sh check

	echo "Secure Boot Cycle Complete" >/dev/console
	;;

stop)
	/usr/bin/umount ${DATA_MOUNT}
	echo 3 >/proc/sys/vm/drop_caches
	;;
esac
