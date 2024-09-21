#############################################################
#
# Summit Software Update
#
#############################################################

SUMMIT_UPDATE_VERSION = local
SUMMIT_UPDATE_SITE = $(SUMMIT_UPDATE_PKGDIR)/files
SUMMIT_UPDATE_SITE_METHOD = local
SUMMIT_UPDATE_LICENSE = Ezurio
SUMMIT_UPDATE_LICENSE_FILES = LICENSE.ezurio

define SUMMIT_UPDATE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin \
		$(@D)/erase_som_nand $(@D)/fw_update $(@D)/ubi_update_support.sh

	$(INSTALL) -D -m 0644 -t ${TARGET_DIR}/etc/swupdate/conf.d \
		${@D}/10-swupdate.conf
endef 

define SUMMIT_UPDATE_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 -t ${TARGET_DIR}/usr/lib/systemd/system/swupdate.service.d \
		${@D}/01-capability.conf
endef

$(eval $(generic-package))
