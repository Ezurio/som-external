#!/bin/sh

MOUNT_POINT=/tmp/ubi_mount_point
DATA_SECRET_SRC=/data/secret
DATA_SECRET_TARGET=${MOUNT_POINT}/secret
DATA_SRC=/data
DATA_TARGET=${MOUNT_POINT}

exit_on_error() {
	[ "${1}" = 1 ] && /bin/umount "${MOUNT_POINT}"
	rmdir "${MOUNT_POINT}"
	echo "${2}"
	exit 1
}

find_ubi_device() {
	ubi_dev=""
	for f in /sys/class/ubi/*; do
		if [ -f "${f}/name" ] &&
			read -r ubi_name <${f}/name &&
			[ "${1}" = "${ubi_name}" ]; then
			ubi_dev="/dev/${f#/sys/class/ubi/}"
			break
		fi
	done
	[ -z "${ubi_dev}" ] && exit_on_error 0 "UBI Volume ${1} Does not Exist"
}

migrate_data() {
	ubiupdatevol -t "${1}" ||
		exit_on_error 0 "Erasing UBI Volume ${1} Failed"

	# Create mount point and mount the data device
	/bin/mount -o noatime,noexec,nosuid,nodev -t ubifs "${1}" "${MOUNT_POINT}" ||
		exit_on_error 0 "Mounting ${DATA_DEVICE} to ${MOUNT_POINT} Failed"

	if [ "${do_data_migration}" -ne 0 ]; then

		# Prepare /data/secret
		if [ -d "${DATA_SECRET_SRC}" ]; then
			mkdir -p "${DATA_SECRET_TARGET}"

			# Needs keyring to access secret data.
			/bin/keyctl link @us @s
			# Target dir is not encrypted anymore after nand erase. Encrypt it before migrating data.
			FSCRYPT_KEY=ffffffffffffffff
			/bin/fscryptctl set_policy ${FSCRYPT_KEY} ${DATA_SECRET_TARGET} ||
				exit_on_error 1 "Directory Encryption.. Failed"
		fi

		cp -fa "${DATA_SRC}"/* "${DATA_TARGET}"/ ||
			exit_on_error 1 "Data Copying.. Failed"

		rm -f ${DATA_SECRET_TARGET}/NetworkManager/system-connections/shared-usb0.nmconnection
	fi

	sync

	# Unmount the data device
	/bin/umount "${MOUNT_POINT}" || exit_on_error 0 "Unmounting ${MOUNT_POINT} Failed"
}

mkdir -p "${MOUNT_POINT}" || exit_on_error 0 "Directory Creation for ${MOUNT_POINT} Failed"

# Don't migrate data from SD
read -r cmdline < /proc/cmdline
case "${cmdline}" in
*/dev/mmc*) do_data_migration=0 ;;
*) #Don't migrate if /data not mounted
	if ! grep -qs "${DATA_SRC} " /proc/mounts; then
		if [ -x /usr/bin/systemd-cat ]; then
			echo "Data from ${DATA_SRC} not migrated, because it was not mounted." | systemd-cat -t "${0}" -p warning
		else
			echo "Data from ${DATA_SRC} not migrated, because it was not mounted." > /dev/stderr
		fi
		do_data_migration=0
	else
		do_data_migration=1
	fi
	;;
esac

for name in ${1}; do
	find_ubi_device "${name}"
	migrate_data "${ubi_dev}"
done

rmdir "${MOUNT_POINT}"
