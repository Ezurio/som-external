ifneq ($(BR2_LRD_DEVEL_BUILD),y)
ADAPTIVE_WW_BINARIES_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
ADAPTIVE_WW_BINARIES_LICENSE = LGPL-2.1
ADAPTIVE_WW_BINARIES_STRIP_COMPONENTS = 0

ADAPTIVE_WW_BINARIES_SOURCE = adaptive_ww$(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_ARCH))-$(ADAPTIVE_WW_BINARIES_VERSION).tar.bz2

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
  ADAPTIVE_WW_BINARIES_SITE = https://files.devops.rfpros.com/builds/linux/adaptive_ww/laird/$(ADAPTIVE_WW_BINARIES_VERSION)
else
  ADAPTIVE_WW_BINARIES_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(ADAPTIVE_WW_BINARIES_VERSION)
endif

define AWM_BINARIES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/usr/bin/adaptive_ww $(TARGET_DIR)/usr/bin/adaptive_ww
endef

define ADAPTIVE_WW_BINARIES_INSTALL_TARGET_CMDS
	$(AWM_BINARIES_INSTALL_TARGET_CMDS)
	$(AWM_BINARIES_CONFIG_INSTALL_TARGET_CMDS)
	$(AWW_BINARIES_CFG_WW_INSTALL_TARGET_CMDS)
endef

ifeq ($(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_MODE_LITE),y)
AWM_PARAMS += -M lite
endif

ifeq ($(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_INTF_AP),y)
AWM_PARAMS += -F AP
else ifeq ($(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_INTF_NONE),y)
AWM_PARAMS += -F NONE
endif

ifneq ($(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_CFG_FILE),"")
AWM_PARAMS += -C $(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_CFG_FILE)
endif

define AWM_BINARIES_CONFIG_INSTALL_TARGET_CMDS
	$(INSTALL) -d "$(TARGET_DIR)/etc/default"
	echo "AWM_ARGS=$(AWM_PARAMS)" > $(TARGET_DIR)/etc/default/adaptive_ww
endef

define ADAPTIVE_WW_BINARIES_INSTALL_INIT_SYSTEMD
	$(INSTALL) -m 0644 -D $(@D)/usr/lib/systemd/system/adaptive_ww.service \
		$(TARGET_DIR)/usr/lib/systemd/system/adaptive_ww.service
endef

define ADAPTIVE_WW_BINARIES_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(@D)/etc/init.d/adaptive_ww $(TARGET_DIR)/etc/init.d/S30adaptive_ww
endef

endif

ifeq ($(BR2_PACKAGE_ADAPTIVE_WW_CFG_WW),y)
define AWW_BINARIES_CFG_WW_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/usr/bin/cww $(TARGET_DIR)/usr/bin/cww
endef
endif

$(eval $(generic-package))
