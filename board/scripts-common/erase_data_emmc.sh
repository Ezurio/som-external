#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

DATA_DEV_SRC=${1}
DATA_DEV_TGT=${2}
MOUNT_POINT=/tmp/transfer_mount_point

DATA_SRC=/data

die() {
	echo "${1}" >&2
	exit 1
}

warning() {
	if [ -x /usr/bin/systemd-cat ]; then
		echo "${1}" | /usr/bin/systemd-cat -t "${0}" -p warning
	else
		echo "${1}" >&2
	fi
}

migrate_data() {
	[ -f /perm/caam/datakey ] && [ -n "${1}" ] || return

	if [ -x /usr/bin/caam-keygen ]; then
		CRYPTO_STR="capi:tk(cbc(aes))-plain :36:logon:datakey:"
		/usr/bin/caam-keygen import /perm/caam/datakey.bb datakey
		/usr/bin/keyctl padd logon datakey: @s < /perm/caam/datakey
	else
		CRYPTO_STR="crypt aes-cbc-plain :32:trusted:datakey"
		/usr/bin/keyctl add trusted datakey "load $(cat /perm/caam/datakey)" @s
	fi

	if [ -x /usr/sbin/blockdev ]; then 
		DATA_SIZE=$(blockdev --getsz "${1}")
	else
		DATA_SIZE=$(/usr/bin/lsblk -ndbo SIZE "${1}")
		DATA_SIZE=$((DATA_SIZE / 512))
	fi

	/usr/sbin/dmsetup -v create data_enc_o --table "0 ${DATA_SIZE} \
		crypt ${CRYPTO_STR} 0 ${1} 0 1 sector_size:512" || \
		die "dm_crypt table creation for ${1} Failed"

	# Wipe data patition
	/usr/sbin/mkfs.ext4 /dev/mapper/data_enc_o || {
		/usr/sbin/dmsetup remove data_enc_o
		die "Formatting ${1} Failed"
	}

	mkdir -p "${MOUNT_POINT}" || {
		/usr/sbin/dmsetup remove data_enc_o
		die "Directory Creation for ${MOUNT_POINT} Failed"
	}

	# Create mount point and mount the data device
	/bin/mount -o noatime,noexec,nosuid,nodev -t auto /dev/mapper/data_enc_o \
		${MOUNT_POINT} || {
		/usr/sbin/dmsetup remove data_enc_o
		rmdir ${MOUNT_POINT}
		die "Mounting ${1} to ${MOUNT_POINT} Failed"
	}

	cp -fa -t ${MOUNT_POINT} ${DATA_SRC}/* || {
		/bin/umount ${MOUNT_POINT} || true
		/usr/sbin/dmsetup remove data_enc_o
		rmdir ${MOUNT_POINT}
		die "Data Copying.. Failed"
	}

	sync

	# Unmount the data device
	/bin/umount "${MOUNT_POINT}" || die "Unmounting ${MOUNT_POINT} Failed"
	/usr/sbin/dmsetup remove data_enc_o
	rmdir "${MOUNT_POINT}"
}

migrate_uboot_var() {
	var=$(fw_printenv -n "${1}")
	[ -z "${var}" ] || fw_setenv -c "${fwenvn}" "${1}" "${var}"
}

# Migrate conf setting
fwenv=$(sed -rn 's,.*(/etc/fw_env_[^ ]+).*,\1,p' /proc/self/mountinfo)
case "${fwenv}" in
	*-a.config)
		fwenvn=${fwenv%-a.config}-b.config
		migrate_uboot_var conf
		migrate_uboot_var RegDomain
		;;
	*-b.config)
		fwenvn=${fwenv%-b.config}-a.config
		migrate_uboot_var conf
		migrate_uboot_var RegDomain
		;;
esac

# Find location for /data
DATA_MOUNT=$(awk "\$2 == \"${DATA_SRC}\" { print \$1 }" /proc/mounts)
[ ! -L "${DATA_MOUNT}" ] || DATA_MOUNT=$(readlink -f "${DATA_MOUNT}")

# Migrate only from secure partitions
case "${DATA_MOUNT}" in
	/dev/dm-*)
		DATA_MOUNT=$(ls "/sys/class/block/${DATA_MOUNT#/dev/}/slaves")
		;;
	*)
		warning "Data from ${DATA_SRC} not migrated, because it was not mounted."
		exit 0
		;;
esac

# Migrate if /data is mounted on the expected target
if [ "${DATA_MOUNT}" = "${DATA_DEV_SRC##*/}" ]; then
	migrate_data "${DATA_DEV_TGT}"
else
	warning "Data from ${DATA_SRC} not migrated, because it was not mounted."
fi
