################################################################################
#
# gattlib
#
################################################################################

GATTLIB_VERSION = 7a2fdbd062679288901b6aed0c620fa4bcfdbcde
GATTLIB_SITE = $(call github,labapart,gattlib,$(GATTLIB_VERSION))
GATTLIB_LICENSE = MIT
GATTLIB_DEPENDENCIES = bluez5_utils
GATTLIB_INSTALL_STAGING = YES

$(eval $(cmake-package))
