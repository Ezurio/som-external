#############################################################
#
# summit-dmcrypt-image
#
#############################################################

SUMMIT_DMCRYPT_IMAGE_SITE = $(SUMMIT_DMCRYPT_IMAGE_PKGDIR)/files
SUMMIT_DMCRYPT_IMAGE_SITE_METHOD = local
SUMMIT_DMCRYPT_IMAGE_LICENSE = Ezurio
SUMMIT_DMCRYPT_IMAGE_LICENSE_FILES = LICENSE.ezurio

SUMMIT_DMCRYPT_IMAGE_DEPENDENCIES = openssl
HOST_SUMMIT_DMCRYPT_IMAGE_DEPENDENCIES = host-openssl

define SUMMIT_DMCRYPT_IMAGE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS)
endef

define SUMMIT_DMCRYPT_IMAGE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin $(@D)/dmcrypt_image
endef

define HOST_SUMMIT_DMCRYPT_IMAGE_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D) $(HOST_CONFIGURE_OPTS)
endef

define HOST_SUMMIT_DMCRYPT_IMAGE_INSTALL_CMDS
	$(INSTALL) -D -m 0755 -t $(HOST_DIR)/bin $(@D)/dmcrypt_image
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
