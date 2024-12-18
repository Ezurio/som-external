################################################################################
#
# Microchip PAC193x Driver
#
################################################################################

PAC193X_SITE = $(PAC193X_PKGDIR)/files
PAC193X_SITE_METHOD = local

PAC193X_LICENSE = GPL-2.0
PAC193X_LICENSE_FILES = \
	COPYING \
	LICENSES/preferred/GPL-2.0

$(eval $(kernel-module))
$(eval $(generic-package))
