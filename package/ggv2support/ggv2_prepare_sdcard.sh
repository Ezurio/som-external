#!/bin/sh

#
# ggv2_prepare_sdcard.sh
#
# Format, prepare, and encrypt a uSD card for use with AWS IoT Greengrass V2
#

systemctl stop ggv2sdmount.service

/bin/keyctl link @us @s

. ggv2_mount_sdcard.sh prepare

systemctl start ggv2sdmount.service
