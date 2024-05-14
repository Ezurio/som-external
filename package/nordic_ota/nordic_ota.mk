#############################################################
#
# Nordic OTA utility
#
#############################################################

NORDIC_OTA_VERSION = local
NORDIC_OTA_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/externals/nordic_ota
NORDIC_OTA_SITE_METHOD = local
NORDIC_OTA_BINDIR = /usr/sbin
NORDIC_OTA_DEPENDENCIES = gattlib

$(eval $(cmake-package))
