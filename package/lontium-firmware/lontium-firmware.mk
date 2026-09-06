LONTIUM_FIRMWARE_VERSION = local
LONTIUM_FIRMWARE_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/lontium-firmware
LONTIUM_FIRMWARE_SITE_METHOD = local

define LONTIUM_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/usr/lib/firmware \
		$(@D)/files/*
	ln -sf $$(basename $(@D)/files/LT2611UXD_*.bin) \
		$(TARGET_DIR)/usr/lib/firmware/lt2611uxd_fw.bin
	ln -sf $$(basename $(@D)/files/LT9611UXD_*.bin) \
		$(TARGET_DIR)/usr/lib/firmware/lt9611c_fw.bin
endef

$(eval $(generic-package))