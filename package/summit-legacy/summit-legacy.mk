#############################################################
#
# Summit Legacy Software
#
#############################################################

define SUMMIT_LEGACY_INSTALL_TARGET_CMDS
	rsync -rlpDWKv $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/lrd-legacy/rootfs-additions/ $(TARGET_DIR)/
endef

$(eval $(generic-package))
