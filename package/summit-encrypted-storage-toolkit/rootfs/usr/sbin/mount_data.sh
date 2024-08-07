#!/bin/sh

set -e

DATA_MOUNT=/data

case $1 in
start)
	. /usr/sbin/boot-rootfs.sh

	DATA_DEVICE=/dev/${rootDevPrefix}$((rootBlock + 1))

	/usr/bin/mount -o noatime,nodev,noexec -t "${rootFsType}" "${DATA_DEVICE}" "${DATA_MOUNT}"

	# Create encrypted data directory
	DATA_SECRET=${DATA_MOUNT}/secret
	mkdir -p ${DATA_SECRET}

	FSCRYPT_KEY=ffffffffffffffff

	/usr/bin/keyctl search %:_builtin_fs_keys logon fscrypt:${FSCRYPT_KEY} @us || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }

	/usr/bin/fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET} >/dev/null || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }

	/usr/sbin/do_factory_reset.sh check

	echo "Secure Boot Cycle Complete" >/dev/console
	;;

stop)
	/usr/bin/umount ${DATA_MOUNT}
	echo 3 >/proc/sys/vm/drop_caches
	;;
esac
