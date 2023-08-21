#############################################################
#
# Laird DCAS
#
#############################################################
DCAS_VERSION = local
DCAS_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/dcas
DCAS_SITE_METHOD = local

ifeq ($(BR2_LRD_DEVEL_BUILD),y)
	DCAS_DEPENDENCIES = sdcsdk
else ifeq ($(BR2_PACKAGE_SUMMIT_SUPPLICANT_BINARIES),y)
	DCAS_DEPENDENCIES = summit-supplicant-binaries
else
	DCAS_DEPENDENCIES = sdcsdk
endif

DCAS_DEPENDENCIES += host-flatcc flatcc libssh

DCAS_MAKE_ENV = $(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) \
	FLATCC="$(HOST_DIR)/usr/bin/flatcc"

define DCAS_BUILD_CMDS
    $(MAKE) -C $(@D) clean
    $(DCAS_MAKE_ENV) $(MAKE) -C $(@D) dcas RELEASE=1
endef

define DCAS_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 700 $(TARGET_DIR)/root/.ssh
	$(INSTALL) -D -t $(TARGET_DIR)/usr/bin -m 755 $(@D)/dcas
	$(INSTALL) -D -t $(TARGET_DIR)/etc -m 755 $(@D)/support/etc/dcas.conf
endef

define DCAS_INSTALL_INIT_SYSV
	$(INSTALL) -D -t $(TARGET_DIR)/etc/init.d -m 755 $(@D)/support/etc/init.d/S99dcas
endef

define DCAS_UNINSTALL_TARGET_CMDS
	rm $(TARGET_DIR)/usr/bin/dcas
	rm $(TARGET_DIR)/etc/dcas.conf
	rm $(TARGET_DIR)/etc/init.d/S99dcas
endef

$(eval $(generic-package))
