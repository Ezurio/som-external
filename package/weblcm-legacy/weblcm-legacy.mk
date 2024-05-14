WEBLCM_LEGACY_VERSION = local
WEBLCM_LEGACY_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/web_lcm
WEBLCM_LEGACY_SITE_METHOD = local

define WEBLCM_LEGACY_INSTALL_TARGET_CMDS
	mkdir -p -m 0775 $(TARGET_DIR)/var/www/docs/plugins
	cp -r $(@D)/plugins/* $(TARGET_DIR)/var/www/docs/plugins

	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/html $(@D)/html/*
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/php $(@D)/php/*
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs $(@D)/webLCM.*
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/assets/css $(@D)/assets/css/*.css
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/assets/img $(@D)/assets/img/*.png
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/assets/js $(@D)/assets/js/*.js
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/var/www/docs/assets/fonts $(@D)/assets/fonts/*
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/lighttpd $(@D)/lighttpd.password
	$(INSTALL) -D -m 0644 $(@D)/lighttpd.conf $(TARGET_DIR)/etc/lighttpd/lighttpd-weblcm.conf
endef

$(eval $(generic-package))
