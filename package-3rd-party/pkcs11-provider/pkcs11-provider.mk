################################################################################
#
# pkcs11-provider
#
################################################################################
PKCS11_PROVIDER_VERSION = 1.1.0
PKCS11_PROVIDER_SITE = $(call github,latchset,pkcs11-provider,v$(PKCS11_PROVIDER_VERSION))
PKCS11_PROVIDER_LICENSE = Apache-2.0
PKCS11_PROVIDER_LICENSE_FILES = LICENSES/Apache-2.0.txt
PKCS11_PROVIDER_DEPENDENCIES = openssl host-pkgconf p11-kit opensc
HOST_PKCS11_PROVIDER_DEPENDENCIES = host-openssl host-pkgconf

ifeq ($(BR2_PACKAGE_PKCS11_PROVIDER_PEM_URI),y)
define PKCS11_PROVIDER_INSTALL_TARGET_CMDS_PEM_URI
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/bin \
		$(@D)/tools/uri2pem.py
endef
endif

define PKCS11_PROVIDER_INSTALL_HOOK_CMDS
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/ssl \
		$(PKCS11_PROVIDER_PKGDIR)/pkcs11module.cnf

	$(PKCS11_PROVIDER_INSTALL_TARGET_CMDS_PEM_URI)
endef

PKCS11_PROVIDER_POST_INSTALL_TARGET_HOOKS += PKCS11_PROVIDER_INSTALL_HOOK_CMDS

define HOST_PKCS11_PROVIDER_INSTALL_CMDS
	$(INSTALL) -d $(HOST_DIR)/usr/lib/ossl-modules
	$(INSTALL) -D -t $(HOST_DIR)/usr/lib/ossl-modules -m 644 $(@D)/build/src/pkcs11.so

	$(INSTALL) -d $(HOST_DIR)/opt/pkcs11-provider/
	$(INSTALL) -m 755 -t $(HOST_DIR)/opt/pkcs11-provider/ $(@D)/tools/uri2pem.py
	$(INSTALL) -m 0644 -t $(HOST_DIR) \
		$(PKCS11_PROVIDER_PKGDIR)/host_pkcs11config.cnf
	$(SED) 's|@@HOST_DIR@@|$(HOST_DIR)|g' \
		$(HOST_DIR)/host_pkcs11config.cnf
endef

$(eval $(meson-package))
$(eval $(host-meson-package))
