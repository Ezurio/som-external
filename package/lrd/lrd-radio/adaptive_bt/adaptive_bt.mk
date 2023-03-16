#############################################################
#
# 60 Series Adaptive Bluetooth Power Daemon
#
#############################################################

ifneq ($(BR2_LRD_NO_RADIO)$(BR2_LRD_DEVEL_BUILD),)
ADAPTIVE_BT_VERSION = local
ADAPTIVE_BT_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/adaptive_bt
ADAPTIVE_BT_SITE_METHOD = local
else
ADAPTIVE_BT_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
ADAPTIVE_BT_SOURCE = adaptive_bt-src-$(ADAPTIVE_BT_VERSION).tar.gz

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
	ADAPTIVE_BT_SITE = https://files.devops.rfpros.com/builds/linux/adaptive_bt/src/$(ADAPTIVE_BT_VERSION)
else
	ADAPTIVE_BT_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(ADAPTIVE_BT_VERSION)
endif
endif

ADAPTIVE_BT_DEPENDENCIES = host-pkgconf libnl bluez5_utils-headers

#
# BUILD
#
define ADAPTIVE_BT_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

#
#Install
#
ifeq ($(BR2_INIT_NONE),y)
define ABT_STARTUP_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0644 -D $(@D)/support/adaptive_bt.service $(TARGET_DIR)/usr/lib/systemd/system/adaptive_bt.service
	$(INSTALL) -m 0755 -D $(@D)/support/adaptive_bt $(TARGET_DIR)/etc/init.d/adaptive_bt
endef
endif

define ADAPTIVE_BT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/adaptive_bt $(TARGET_DIR)/usr/bin/adaptive_bt
	$(ABT_STARTUP_INSTALL_TARGET_CMDS)
endef

define ADAPTIVE_BT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -m 0644 -D $(@D)/support/adaptive_bt.service \
		$(TARGET_DIR)/usr/lib/systemd/system/adaptive_bt.service
endef

define ADAPTIVE_BT_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(@D)/support/adaptive_bt $(TARGET_DIR)/etc/init.d/S96adaptive_bt
endef

#
# Uninstall
#
define ADAPTIVE_BT_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/bin/adaptive_bt
endef

$(eval $(generic-package))
