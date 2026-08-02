#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -e

DATA_MOUNT=/data
DATA_SECRET=${DATA_MOUNT}/secret
FSCRYPT_V2_KEY=/perm/caam/fscrypt-data.key
FSCRYPT_V2_TRUSTED_KEY=fscrypt-data

mount_fscrypt_v1() {
	FSCRYPT_KEY=ffffffffffffffff

	/usr/bin/mount -o noatime,nodev,nosuid,noexec -t "${mountFsType:?}" \
		"${DATA_DEVICE}" "${DATA_MOUNT}"

	# Create encrypted data directory
	mkdir -p ${DATA_SECRET}

	/usr/bin/keyctl search %:_builtin_fs_keys logon fscrypt:${FSCRYPT_KEY} @us || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }

	/usr/bin/fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET} >/dev/null || \
		{ /usr/bin/umount ${DATA_MOUNT}; exit 1; }
}

mount_fscrypt_v2() {
	/usr/bin/mount -o noatime,nodev,nosuid,noexec -t "${mountFsType:?}" \
		"${DATA_DEVICE}" "${DATA_MOUNT}" || return 1

	mkdir -p -m 700 /perm/caam || {
		/usr/bin/umount "${DATA_MOUNT}"
		return 1
	}
	chmod 700 /perm/caam

	if [ -f "${FSCRYPT_V2_KEY}" ]; then
		TRUSTED_KEY_ID=$(/usr/bin/keyctl add trusted "${FSCRYPT_V2_TRUSTED_KEY}" \
			"load $(cat "${FSCRYPT_V2_KEY}")" @s) || {
			/usr/bin/umount "${DATA_MOUNT}"
			return 1
		}
	else
		TRUSTED_KEY_ID=$(/usr/bin/keyctl add trusted "${FSCRYPT_V2_TRUSTED_KEY}" \
			"new 64" @s) || {
			/usr/bin/umount "${DATA_MOUNT}"
			return 1
		}
		(umask 077; /usr/bin/keyctl pipe "${TRUSTED_KEY_ID}" > "${FSCRYPT_V2_KEY}") || {
			/usr/bin/umount "${DATA_MOUNT}"
			return 1
		}
	fi
	chmod 600 "${FSCRYPT_V2_KEY}"

	# fscryptctl reads the raw key material from the trusted key's
	# in-kernel payload by ID; it never transits userspace.
	FSCRYPT_KEY=$(/usr/bin/fscryptctl add_key --key-id="${TRUSTED_KEY_ID}" "${DATA_MOUNT}") || {
		/usr/bin/umount "${DATA_MOUNT}"
		return 1
	}

	mkdir -p "${DATA_SECRET}" || {
		/usr/bin/umount "${DATA_MOUNT}"
		return 1
	}

	/usr/bin/fscryptctl set_policy "${FSCRYPT_KEY}" "${DATA_SECRET}" >/dev/null || {
		/usr/bin/umount "${DATA_MOUNT}"
		return 1
	}
}

umount_fscrypt() {
	/usr/bin/umount ${DATA_MOUNT}
	echo 3 >/proc/sys/vm/drop_caches
}

umount_fscrypt_v1() {
	umount_fscrypt
}

umount_fscrypt_v2() {
	umount_fscrypt
}

mount_dmcrypt() {
	if [ -x /usr/sbin/blockdev ]; then
		DATA_SIZE=$(blockdev --getsz "${DATA_DEVICE}")
	else
		DATA_SIZE=$(/usr/bin/lsblk -ndbo SIZE "${DATA_DEVICE}")
		DATA_SIZE=$((DATA_SIZE / 512))
	fi

	if [ -x /usr/bin/caam-keygen ]; then
		if [ ! -f /perm/caam/datakey ] ||
			! /usr/bin/caam-keygen import /perm/caam/datakey.bb datakey
		then
			/usr/bin/caam-keygen create datakey ecb -s 16
		fi
		/usr/bin/keyctl padd logon datakey: @s < /perm/caam/datakey
		CRYPTO_STR="capi:tk(cbc(aes))-plain :36:logon:datakey:"
	else
		[ -f /perm/caam/datakey ] &&
			KEY_ID=$(/usr/bin/keyctl add trusted datakey \
				"load $(cat /perm/caam/datakey)" @s) ||
		{
			mkdir -p /perm/caam
			KEY_ID=$(/usr/bin/keyctl add trusted datakey "new 64" @s)
			/usr/bin/keyctl pipe "${KEY_ID}" > /perm/caam/datakey
		}
		CRYPTO_STR="aes-xts-plain64 :64:trusted:datakey"
	fi

	/usr/sbin/dmsetup -v create data_enc --table \
		"0 ${DATA_SIZE} crypt ${CRYPTO_STR} 0 ${DATA_DEVICE} 0 1 sector_size:512"

	[ "$(/usr/sbin/blkid -p -s TYPE -o value /dev/mapper/data_enc)" = "ext4" ] || \
		/usr/sbin/mkfs.ext4 /dev/mapper/data_enc

	/usr/bin/mount -o noatime,noexec,nosuid,nodev -t auto \
		/dev/mapper/data_enc ${DATA_MOUNT} || {
		/usr/sbin/dmsetup remove data_enc
		die "Mounting ${DATA_DEVICE} to ${DATA_MOUNT} Failed"
	}

	# Create encrypted data directory
	mkdir -p ${DATA_SECRET}
}

umount_dmcrypt() {
	/usr/bin/umount ${DATA_MOUNT}
	/usr/sbin/dmsetup remove data_enc
	echo 3 >/proc/sys/vm/drop_caches
}

anymount() {
	case "${rootDevType:?}" in
		ubi)
			case "${soc_id:?}" in
				sama5d3*)
					# sama5d3 lacks trusted-key support; it relies on a u-boot-
					# provisioned key in the logon keyring, so it must use v1.
					"${1}_fscrypt_v1"
					;;
				*)
					"${1}_fscrypt_v2"
					;;
			esac
			;;
		*)
			"${1}_dmcrypt"
			;;
	esac
}

# shellcheck source=/dev/null
. /usr/bin/boot-rootfs.sh

getSocId

case "${1}" in
start)
	DATA_DEVICE=/dev/$(getPart rootfs_data)

	anymount 'mount'

	/usr/bin/do_factory_reset.sh check || { anymount 'umount' ; exit 1; }

	echo "Secure Boot Cycle Complete" >/dev/console
	;;

stop)
	anymount 'umount'
	;;

*)
	echo "Usage: ${0} <start|stop>"
	exit 1
	;;
esac
