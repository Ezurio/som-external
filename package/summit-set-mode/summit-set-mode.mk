#############################################################
#
# Summit board set mode package
#
#############################################################
SUMMIT_SET_MODE_VERSION = local
SUMMIT_SET_MODE_SITE = $(SUMMIT_SET_MODE_PKGDIR)/files
SUMMIT_SET_MODE_SITE_METHOD = local
SUMMIT_SET_MODE_LICENSE = Ezurio
SUMMIT_SET_MODE_LICENSE_FILES = LICENSE.ezurio

define SUMMIT_SET_MODE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0744 -t $(TARGET_DIR)/usr/bin $(@D)/set-mode
endef

$(eval $(generic-package))
