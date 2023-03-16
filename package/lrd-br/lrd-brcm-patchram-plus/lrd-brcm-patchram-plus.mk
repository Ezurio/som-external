################################################################################
#
# lrd-brcm-patchram-plus
#
################################################################################

LRD_BRCM_PATCHRAM_PLUS_VERSION = local
LRD_BRCM_PATCHRAM_PLUS_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/brcm_patchram
LRD_BRCM_PATCHRAM_PLUS_SITE_METHOD = local
LRD_BRCM_PATCHRAM_PLUS_LICENSE = Apache-2.0
LRD_BRCM_PATCHRAM_PLUS_LICENSE_FILES = LICENSE

ifeq ($(BR2_PACKAGE_BLUEZ4_UTILS),y)
LRD_BRCM_PATCHRAM_PLUS_DEPENDENCIES = bluez4_utils
else
LRD_BRCM_PATCHRAM_PLUS_DEPENDENCIES = bluez5_utils
endif

define LRD_BRCM_PATCHRAM_PLUS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) brcm_patchram_plus
endef

define LRD_BRCM_PATCHRAM_PLUS_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/brcm_patchram_plus $(TARGET_DIR)/usr/bin/
endef

$(eval $(generic-package))
