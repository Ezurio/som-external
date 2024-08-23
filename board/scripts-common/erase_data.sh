#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2018 Ezurio

MOUNT_POINT=/tmp/transfer_mount_point
DATA_SECRET_TARGET=${MOUNT_POINT}/secret
DATA_SRC=/data
DATA_SECRET_SRC=${DATA_SRC}/secret

die() {
	echo "${1}" >&2
	exit 1
}

warning() {
	if [ -x /usr/bin/systemd-cat ]; then
		echo "${1}" | systemd-cat -t "${0}" -p warning
	else
		echo "${1}" >&2
	fi
}

cleanup() {
	if [ -d "${MOUNT_POINT}" ]; then
		/bin/umount ${MOUNT_POINT} || true
		rmdir ${MOUNT_POINT}
	fi
}

find_ubi_device() {
	f=$(grep -lxF "${1}" /sys/class/ubi/ubi0_*/name) ||
		die "UBI volume for ${1} not found"

	f=${f#/sys/class/ubi/}
	f=${f%%/name}
	echo "/dev/${f}"
}

migrate_data() {
	# Wipe ubi partition
	/usr/sbin/ubiupdatevol "${1}" -t ||
		die "Erasing UBI Volume ${1} Failed"

	# Mount the data device, this ensures that wipe have completed
	/bin/mount -o noatime,noexec,nosuid,nodev -t ubifs "${1}" "${MOUNT_POINT}" ||
		die "Mounting ${DATA_DEVICE} to ${MOUNT_POINT} Failed"

	if ${do_data_migration}; then
		# Prepare /data/secret
		if [ -d "${DATA_SECRET_SRC}" ]; then
			mkdir -p "${DATA_SECRET_TARGET}"

			# Needs keyring to access secret data.
			/bin/keyctl link @us @s
			# Target dir is not encrypted anymore after nand erase. Encrypt it before migrating data.
			FSCRYPT_KEY=ffffffffffffffff
			/bin/fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET_TARGET} ||
				die "Directory Encryption.. Failed"
		fi

		cp -fa -t ${MOUNT_POINT} ${DATA_SRC}/* ||
			die "Data Copying.. Failed"

		rm -f ${DATA_SECRET_TARGET}/NetworkManager/system-connections/shared-usb0.nmconnection
	fi

	sync

	# Unmount the data device
	/bin/umount "${MOUNT_POINT}" ||
		die "Unmounting ${MOUNT_POINT} Failed"
}

# Don't migrate data from SD
read -r cmdline < /proc/cmdline
case "${cmdline}" in
*/dev/mmc*)
	do_data_migration=false
	;;

*)
	# Don't migrate if /data not mounted
	if grep -qsF "${DATA_SRC} " /proc/mounts; then
		do_data_migration=true
	else
		warning "Data from ${DATA_SRC} not migrated, because it was not mounted."
		do_data_migration=false
	fi
	;;
esac

trap cleanup EXIT

mkdir -p "${MOUNT_POINT}" ||
	die "Directory Creation for ${MOUNT_POINT} Failed"

for name in ${1}; do
	# Clean partition and migrate data if neeeded
	migrate_data "$(find_ubi_device "${name}")"
done

rmdir "${MOUNT_POINT}"
