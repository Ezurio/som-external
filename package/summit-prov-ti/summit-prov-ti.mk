#####################################################################
# Summit Provisioning Service for TI AM6x
#####################################################################

SUMMIT_PROV_TI_SITE = $(SUMMIT_PROV_TI_PKGDIR)/files
SUMMIT_PROV_TI_SITE_METHOD = local
SUMMIT_PROV_TI_LICENSE = Ezurio, GPL-2.0+
SUMMIT_PROV_TI_LICENSE_FILES = LICENSE.ezurio
SUMMIT_PROV_TI_MODULE_MAKE_OPTS += \
	CFLAGS=-I$(STAGING_DIR)/usr/include

define SUMMIT_PROV_TI_INSTALL_TARGET_HOOK_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/sbin $(@D)/summit-prov-ti.sh
endef

SUMMIT_PROV_TI_POST_INSTALL_TARGET_HOOKS += SUMMIT_PROV_TI_INSTALL_TARGET_HOOK_CMDS

define SUMMIT_PROV_TI_INSTALL_INIT_SYSV
	$(INSTALL) -D -t $(TARGET_DIR)/etc/init.d -m 755 $(@D)/S49summitprovti
endef

# On secure images the data partition is encrypted and mounted by
# mount_data.service; order provisioning after it, as the Yocto recipe does.
ifeq ($(BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT),y)
define SUMMIT_PROV_TI_SERVICE_MOUNT_DATA
	$(SED) 's/^\(After\|Requires\)=mount_boot\.service$$/& mount_data.service/' \
		$(TARGET_DIR)/usr/lib/systemd/system/summit-prov-ti.service
endef
endif

define SUMMIT_PROV_TI_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -t $(TARGET_DIR)/usr/lib/systemd/system -m 644 $(@D)/summit-prov-ti.service
	$(SUMMIT_PROV_TI_SERVICE_MOUNT_DATA)
endef

$(eval $(kernel-module))
$(eval $(generic-package))
