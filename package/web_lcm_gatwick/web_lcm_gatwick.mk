WEB_LCM_GATWICK_VERSION = local
WEB_LCM_GATWICK_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/web_lcm_gatwick
WEB_LCM_GATWICK_SITE_METHOD = local
WEB_LCM_GATWICK_DEPENDENCIES = host-nodejs host-composer php_sdk

define WEB_LCM_GATWICK_BUILD_CMDS
	cd $(@D); cp $(TARGET_DIR)/var/www/docs/lrd_php_sdk.php $(@D)/api/lib/

	cd $(@D); \
		PATH=$(BR_PATH) \
		$(HOST_NPM) install $(@D)

	cd $(@D); \
		PATH=$(BR_PATH) \
		$(HOST_NPM) run ng -- build --prod \
		--sourceMap=$(if $(BR2_WEB_LCM_GATWICK_SOURCEMAP),true,false) \
		--aot=$(if $(BR2_WEB_LCM_GATWICK_AOT),true,false)

	cd $(@D); \
		PATH=$(BR_PATH) \
		$(HOST_DIR)/usr/bin/php $(HOST_DIR)/usr/bin/composer install --no-dev --ignore-platform-reqs --no-suggest --prefer-dist \
		$(if $(BR2_WEB_LCM_GATWICK_OPTIMIZE_AUTOLOADER),--optimize-autoloader)

endef

define WEB_LCM_GATWICK_INSTALL_TARGET_CMDS
	mkdir -p -m 0775 $(TARGET_DIR)/var/www/http/
	cp -rf $(@D)/api $(TARGET_DIR)/var/www/
	cp -rf $(@D)/dist/* $(TARGET_DIR)/var/www/http/

	mv $(TARGET_DIR)/var/www/api/api.php $(TARGET_DIR)/var/www/http/

	$(INSTALL) -D -m 0755 $(@D)/lighttpd.conf \
				$(@D)/lighttpd.password \
				$(TARGET_DIR)/etc/lighttpd
endef

$(eval $(generic-package))
