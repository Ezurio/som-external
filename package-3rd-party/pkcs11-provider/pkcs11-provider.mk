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

ifeq ($(BR2_PACKAGE_PKCS11_PROVIDER_PEM_URI),y)
define PKCS11_PROVIDER_INSTALL_TARGET_CMDS_PEM_URI
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/bin \
		$(@D)/tools/uri2pem.py
endef
endif

define PKCS11_PROVIDER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/usr/lib/ossl-modules \
		$(@D)/build/src/pkcs11.so

	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/ssl \
		$(PKCS11_PROVIDER_PKGDIR)/files/pkcs11module.cnf

	$(PKCS11_PROVIDER_INSTALL_TARGET_CMDS_PEM_URI)
endef

$(eval $(meson-package))
