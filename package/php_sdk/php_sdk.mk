#############################################################
#
# PHP SDK
#
#############################################################

PHP_SDK_VERSION = local
PHP_SDK_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/php_sdk
PHP_SDK_SITE_METHOD = local
PHP_SDK_LICENSE = Ezurio
PHP_SDK_LICENSE_FILES = LICENSE.ezurio

PHP_SDK_DEPENDENCIES = php host-swig

ifeq ($(BR2_PACKAGE_SUMMIT_SUPPLICANT),y)
	PHP_SDK_DEPENDENCIES += summit-supplicant
else
	PHP_SDK_DEPENDENCIES += sdcsdk
endif

PHP_SDK_MAKE_ENV = \
	INCLUDES="-I$(STAGING_DIR)/usr/include/php \
		-I$(STAGING_DIR)/usr/include/php/Zend \
		-I$(STAGING_DIR)/usr/include/php/main \
		-I$(STAGING_DIR)/usr/include/php/TSRM"

define PHP_SDK_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(PHP_SDK_MAKE_ENV) $(MAKE) -C $(@D)
endef

ifeq ($(BR2_PACKAGE_PHP_SDK_TEST),y)
define PHP_SDK_INSTALL_TEST
	$(INSTALL) -D -m 644 $(@D)/examples/lrd_sdk_GetVersion.php \
		$(TARGET_DIR)/var/www/docs/examples/lrd_sdk_GetVersion.php
endef
endif

define PHP_SDK_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/usr/lib/ $(@D)/lrd_php_sdk.so*
	ln -rsf $(TARGET_DIR)/usr/lib/lrd_php_sdk.so.* $(TARGET_DIR)/usr/lib/lrd_php_sdk.so
	$(PHP_SDK_INSTALL_TEST)
endef

define PHP_SDK_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/lib/lrd_php_sdk.so*
endef

$(eval $(generic-package))
