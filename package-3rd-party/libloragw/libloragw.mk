################################################################################
#
# libloragw
#
################################################################################

LIBLORAGW_VERSION = v4.1.3
LIBLORAGW_SITE = $(call github,Lora-net,lora_gateway,$(LIBLORAGW_VERSION))
LIBLORAGW_INSTALL_STAGING = YES
LIBLORAGW_LICENSE = BSD-3-Clause
LIBLORAGW_LICENSE_FILES = LICENSE

define LIBLORAGW_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D)
endef

define LIBLORAGW_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/lib/libloragw \
		$(@D)/libloragw/libloragw.a $(@D)/libloragw/library.cfg
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/lib/libloragw/inc $(@D)/libloragw/inc/*
endef

define LIBLORAGW_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/opt/lora/
	$(INSTALL) -D -m 755 $(@D)/reset_lgw.sh $(TARGET_DIR)/usr/sbin/reset_lgw
endef

$(eval $(generic-package))
