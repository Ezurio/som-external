#############################################################
#
# Summit DCAL
#
#############################################################

DCAL_VERSION = local
DCAL_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/dcal
DCAL_SITE_METHOD = local
DCAL_LICENSE = Ezurio
DCAL_LICENSE_FILES = LICENSE.ezurio
DCAL_INSTALL_STAGING = YES
DCAL_DEPENDENCIES += flatcc libssh

ifeq ($(BR2_PACKAGE_DCAL_TEST_APPS),y)
define DCAL_BUILD_EXAMPLE_APPS
    $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D) test_apps
endef
endif

define DCAL_BUILD_CMDS
    $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D) dcal
    $(DCAL_BUILD_EXAMPLE_APPS)
endef

ifeq ($(BR2_PACKAGE_DCAL_TEST_APPS),y)
define DCAL_INSTALL_EXAMPLE_APPS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/user/share/dcal/examples $(@D)/apps/examples/*
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/user/share/dcal/unit-tests $(@D)/apps/unit-tests/*
endef
endif

define DCAL_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/lib $(@D)/api/libdcal.so.1.0 $(@D)/api/libsessopt.a
	ln -fs libdcal.so.1.0 $(STAGING_DIR)/usr/lib/libdcal.so.1
	ln -fs libdcal.so.1.0 $(STAGING_DIR)/usr/lib/libdcal.so
endef

define DCAL_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/usr/lib $(@D)/api/libdcal.so.1.0
	ln -fs libdcal.so.1.0 $(TARGET_DIR)/usr/lib/libdcal.so.1
	$(DCAL_INSTALL_EXAMPLE_APPS)
endef

$(eval $(generic-package))
