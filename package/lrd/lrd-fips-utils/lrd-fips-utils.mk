
ifeq ($(BR2_PACKAGE_LIBOPENSSL_3_0),y)

LRD_FIPS_UTILS_VERSION = local
LRD_FIPS_UTILS_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/lrd-fips-utils
LRD_FIPS_UTILS_SITE_METHOD = local
LRD_FIPS_UTILS_DEPENDENCIES = openssl

LRD_FIPS_UTILS_MAKE_ENV = $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) \
	FLATCC="$(HOST_DIR)/usr/bin/flatcc"

define LRD_FIPS_UTILS_BUILD_CMDS
    $(MAKE) -C $(@D) clean
    $(LRD_FIPS_UTILS_MAKE_ENV) $(MAKE) -C $(@D)
endef

define LRD_FIPS_UTILS_INSTALL_OSSL_FIPSLOAD
	$(INSTALL) -D -t $(TARGET_DIR)/usr/bin -m 755 $(@D)/ossl-fipsload
endef

define LRD_FIPS_UTILS_UNINSTALL_OSSL_FIPSLOAD
	rm $(TARGET_DIR)/usr/bin/ossl-fipsload
endef

endif

ifeq ($(BR2_PACKAGE_LRD_LEGACY),y)
define LRD_FIPS_UTILS_INSTALL_FIPS_SET
	$(INSTALL) -D -m 755 $(LRD_FIPS_UTILS_PKGDIR)/fips-set.legacy \
		$(TARGET_DIR)/usr/bin/fips-set
endef
else
define LRD_FIPS_UTILS_INSTALL_FIPS_SET
	$(INSTALL) -D -m 755 $(LRD_FIPS_UTILS_PKGDIR)/fips-set \
		$(TARGET_DIR)/usr/bin/fips-set
endef
endif

define LRD_FIPS_UTILS_INSTALL_TARGET_CMDS
	$(LRD_FIPS_UTILS_INSTALL_FIPS_SET)
	$(LRD_FIPS_UTILS_INSTALL_OSSL_FIPSLOAD)
endef
define LRD_FIPS_UTILS_UNINSTALL_TARGET_CMDS

rm $(TARGET_DIR)/usr/bin/ossl-fipsload
	rm $(TARGET_DIR)/usr/bin/fips-set
	$(LRD_FIPS_UTILS_UNINSTALL_OSSL_FIPSLOAD)
endef

$(eval $(generic-package))
