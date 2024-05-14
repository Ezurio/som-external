#!/bin/sh

WEBLCM_USER_SETTINGS_FILE="/data/secret/weblcm-python/weblcm-settings.ini"
SUMMIT_RCM_USER_SETTINGS_FILE="/data/secret/summit-rcm/summit-rcm-settings.ini"

# If the summit-rcm secret directory does not exist (in the event of an upgrade from WebLCM), create
# it and copy the default SSL certificates
if [ ! -d /data/secret/summit-rcm ]; then
    echo "Summit RCM configuration not detected, restoring settings"
    cp -r /usr/share/factory/etc/secret/summit-rcm /data/secret

    # Copy the WebLCM user settings to Summit RCM
    [ -f $WEBLCM_USER_SETTINGS_FILE ] && cp $WEBLCM_USER_SETTINGS_FILE $SUMMIT_RCM_USER_SETTINGS_FILE
fi
