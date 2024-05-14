#!/bin/sh
# Always copy over system connections, as the host connection is critical
cp -r ${FACTORY_SETTING_SECRET_SOURCE}/NetworkManager/system-connections ${USER_SETTINGS_SECRET_TARGET}/NetworkManager
