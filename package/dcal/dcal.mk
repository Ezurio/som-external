#############################################################
#
# Laird DCAL
#
#############################################################

DCAL_VERSION = local
DCAL_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/dcal
DCAL_SITE_METHOD = local

DCAL_DEPENDENCIES += flatcc libssh

DCAL_MAKE_ENV = $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS)

ifeq ($(BR2_PACKAGE_DCAL_TEST_APPS),y)
define BUILD_EXAMPLE_APPS
    $(DCAL_MAKE_ENV) $(MAKE) -C $(@D) test_clean
    $(DCAL_MAKE_ENV) $(MAKE) -C $(@D) test_apps
endef
endif

define DCAL_BUILD_CMDS
    $(DCAL_MAKE_ENV) $(MAKE) -C $(@D) clean
    $(DCAL_MAKE_ENV) $(MAKE) -C $(@D) dcal
    $(BUILD_EXAMPLE_APPS)
endef

ifeq ($(BR2_PACKAGE_DCAL_TEST_APPS),y)
define INSTALL_EXAMPLE_APPS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/user/share/dcal/examples/ $(@D)/apps/examples/*
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/user/share/dcal/unit-tests/ $(@D)/apps/unit-tests/*
endef
endif

define DCAL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 644 $(@D)/api/libdcal.so.1.0 $(TARGET_DIR)/usr/lib/libdcal.so.1.0
	cd $(TARGET_DIR)/usr/lib && ln -fs libdcal.so.1.0 libdcal.so.1
	cd $(TARGET_DIR)/usr/lib && ln -fs libdcal.so.1.0 libdcal.so
	$(INSTALL_EXAMPLE_APPS)
endef

define DCAL_UNINSTALL_TARGET_CMDS
	rm $(TARGET_DIR)/usr/lib/libdcal.so
	rm $(TARGET_DIR)/usr/lib/libdcal.so.1
	rm $(TARGET_DIR)/usr/lib/libdcal.so.1.0
	rm -rf $(TARGET_DIR)/user/share/dcal/
endef

$(eval $(generic-package))
