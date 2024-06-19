##########################################################################
# Sentrius IG60 summit_bt_utils
##########################################################################

SUMMIT_BT_UTILS_VERSION = local
SUMMIT_BT_UTILS_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/lrd-bt-utils
SUMMIT_BT_UTILS_SITE_METHOD = local
SUMMIT_BT_UTILS_LICENSE = Ezurio
SUMMIT_BT_UTILS_LICENSE_FILES = LICENSE.ezurio
SUMMIT_BT_UTILS_SETUP_TYPE = setuptools

$(eval $(python-package))
