################################################################################
#
# pkcs11-provider
#
################################################################################
PKCS11_PROVIDER_VERSION = v1.1.0
PKCS11_PROVIDER_SITE_METHOD = git
PKCS11_PROVIDER_GIT_SUBMODULES = yes
PKCS11_PROVIDER_SITE = https://github.com/latchset/pkcs11-provider.git
PKCS11_PROVIDER_LICENSE = Apache-2.0
PKCS11_PROVIDER_LICENSE_FILES = LICENSES/Apache-2.0.txt
PKCS11_PROVIDER_DEPENDENCIES = openssl host-pkgconf p11-kit opensc

define PKCS11_PROVIDER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MESON) compile -C $(@D)/build
endef

define PKCS11_PROVIDER_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/lib/ossl-modules
	$(INSTALL) -D -t $(TARGET_DIR)/usr/lib/ossl-modules -m 755 $(@D)/build/src/pkcs11.so

	$(INSTALL) -d $(TARGET_DIR)/etc/ssl
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/ssl \
		$(PKCS11_PROVIDER_PKGDIR)/files/pkcs11module.cnf

	$(INSTALL) -d $(TARGET_DIR)/opt/pkcs11-provider/
	$(INSTALL) -m 755 -t $(TARGET_DIR)/opt/pkcs11-provider/ $(@D)/tools/uri2pem.py
endef

define HOST_PKCS11_PROVIDER_INSTALL_CMDS
	$(INSTALL) -d $(HOST_DIR)/opt/pkcs11-provider/
	$(INSTALL) -m 755 -t $(HOST_DIR)/opt/pkcs11-provider/ $(@D)/tools/uri2pem.py
endef

$(eval $(meson-package))
$(eval $(host-meson-package))
