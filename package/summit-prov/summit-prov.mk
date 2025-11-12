#####################################################################
# Summit Provisioning Service
#####################################################################

SUMMIT_PROV_SITE = $(SUMMIT_PROV_PKGDIR)/files
SUMMIT_PROV_SITE_METHOD = local
SUMMIT_PROV_LICENSE = Ezurio, GPL-2.0+
SUMMIT_PROV_LICENSE_FILES = LICENSE.ezurio
SUMMIT_PROV_MODULE_MAKE_OPTS += \
	CFLAGS=-I$(STAGING_DIR)/usr/include

define SUMMIT_PROV_INSTALL_TARGET_HOOK_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/sbin $(@D)/summit-prov.sh
endef

SUMMIT_PROV_POST_INSTALL_TARGET_HOOKS += SUMMIT_PROV_INSTALL_TARGET_HOOK_CMDS

define SUMMIT_PROV_INSTALL_INIT_SYSV
	$(INSTALL) -D -t $(TARGET_DIR)/etc/init.d -m 644 $(@D)/S49summitprovd
endef

define SUMMIT_PROV_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -t $(TARGET_DIR)/usr/lib/systemd/system -m 644 $(@D)/summit-prov.service
endef

$(eval $(kernel-module))
$(eval $(generic-package))
