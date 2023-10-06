#!/bin/sh

FACTORY_SETTING_SECRET_SOURCE=/usr/share/factory/etc/secret
FACTORY_SETTING_MISC_SOURCE=/usr/share/factory/etc/misc
FACTORY_SETTING_DEFAULT_ZONE=/usr/share/zoneinfo

USER_SETTINGS_SECRET_TARGET=/data/secret
USER_SETTINGS_MISC_TARGET=/data/misc

FACTORY_SETTING_LOCALTIME=/etc/localtime
FACTORY_SETTING_TIMEZONE=/etc/timezone
FACTORY_SETTING_ADJTIME_FILE=/etc/adjtime

BLUETOOTH_STATE_DIR=${USER_SETTINGS_SECRET_TARGET}/lib/bluetooth
RESET_INIDICATOR=/data/.factory_reset

exit_on_error() {
	echo "${1}"
	exit 1
}

do_check_and_reset() {
	# Check if reset has been requested
	if [ -f "${RESET_INIDICATOR}" ]; then
		# Delete all user data, but not the /data/secret dir as it is encrypted.
		find /data -maxdepth 1 -mindepth 1 ! -name secret -exec rm -fr {} \;
		rm -fr ${USER_SETTINGS_SECRET_TARGET}/*
		# Run factory reset hooks for external components
		for hook_sh in "/usr/sbin/factory_reset_*.sh"; do
			if [ -x ${hook_sh} ]; then
				. ${hook_sh}
			fi
		done

	# Check if secret directory has been populated, do not blow away settings
	elif [ -d "${USER_SETTINGS_SECRET_TARGET}/NetworkManager" ]; then
		# Always copy over system connections, as the host connection is critical
		cp -r ${FACTORY_SETTING_SECRET_SOURCE}/NetworkManager/system-connections ${USER_SETTINGS_SECRET_TARGET}/NetworkManager
		return
	fi

	mkdir -p ${BLUETOOTH_STATE_DIR}

	cp -r ${FACTORY_SETTING_SECRET_SOURCE}/* ${USER_SETTINGS_SECRET_TARGET} || \
		exit_on_error "Copying factory default files failed"

	mkdir -p ${USER_SETTINGS_MISC_TARGET}

	cp -r ${FACTORY_SETTING_MISC_SOURCE}/* ${USER_SETTINGS_MISC_TARGET} || \
		exit_on_error "Copying factory default files failed"

	# timezone file should be included in backup but we create a default if it
	# is not present. Localtime requires a valid timezone.
	[ -f "${USER_SETTINGS_MISC_TARGET}/timezone" ] || \
		echo "Etc/UTC" > "${USER_SETTINGS_MISC_TARGET}/timezone"

	ln -sf ${FACTORY_SETTING_DEFAULT_ZONE}/$(cat ${FACTORY_SETTING_TIMEZONE}) $(readlink ${FACTORY_SETTING_LOCALTIME}) || \
		exit_on_error "Unable to create localtime link"

	touch "${FACTORY_SETTING_ADJTIME_FILE}" || exit_on_error "unable to create adjtime file"

	sync
}

case "${1}" in
	check)
		do_check_and_reset
		;;

	reset)
		touch ${RESET_INIDICATOR}
		;;

	*)
		echo "Usage: ${0} <reset | check>"
		exit -1
		;;
esac
