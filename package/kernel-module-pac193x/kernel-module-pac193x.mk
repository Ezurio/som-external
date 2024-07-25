################################################################################
#
# Microchip PAC193x Driver
#
################################################################################

KERNEL_MODULE_PAC193X_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/kernel-module-pac193x/files
KERNEL_MODULE_PAC193X_SITE_METHOD = local

KERNEL_MODULE_PAC193X_LICENSE = GPL-2.0
KERNEL_MODULE_PAC193X_LICENSE_FILES = \
	COPYING \
	LICENSES/preferred/GPL-2.0

$(eval $(kernel-module))
$(eval $(generic-package))
