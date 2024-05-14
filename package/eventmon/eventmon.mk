#############################################################
#
# Summit Event Monitor
#
#############################################################

EVENTMON_VERSION = local
EVENTMON_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/eventmon
EVENTMON_SITE_METHOD = local

ifeq ($(BR2_LRD_DEVEL_BUILD),y)
	EVENTMON_DEPENDENCIES = sdcsdk
else ifeq ($(BR2_PACKAGE_SUMMIT_SUPPLICANT_BINARIES),y)
	EVENTMON_DEPENDENCIES = summit-supplicant-binaries
else
	EVENTMON_DEPENDENCIES = sdcsdk
endif

define EVENTMON_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define EVENTMON_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/event_mon $(TARGET_DIR)/usr/bin/event_mon
endef

define EVENTMON_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/bin/event_mon
endef

$(eval $(generic-package))
