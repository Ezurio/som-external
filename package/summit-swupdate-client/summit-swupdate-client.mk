################################################################################
#
# summit-swupdate-client
#
################################################################################

SUMMIT_SWUPDATE_CLIENT_VERSION = local
SUMMIT_SWUPDATE_CLIENT_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/lrd-userspace-examples/swclient
SUMMIT_SWUPDATE_CLIENT_SITE_METHOD = local
SUMMIT_SWUPDATE_CLIENT_SETUP_TYPE = setuptools
SUMMIT_SWUPDATE_CLIENT_DEPENDENCIES = swupdate

$(eval $(python-package))
