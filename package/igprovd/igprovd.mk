#####################################################################
# Summit IG igprovd
#####################################################################

IGPROVD_VERSION = local
IGPROVD_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/igprovd
IGPROVD_SITE_METHOD = local
IGPROVD_LICENSE = Ezurio
IGPROVD_LICENSE_FILES = LICENSE.ezurio
IGPROVD_SETUP_TYPE = setuptools

define IGPROVD_INSTALL_INIT_SYSTEMD
        $(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/systemd/system \
		$(IGPROVD_PKGDIR)/igprovd.service $(IGPROVD_PKGDIR)/edge.service
        $(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/dbus-1/system.d \
		$(IGPROVD_PKGDIR)/com.lairdtech.IG.ProvService.conf
endef

$(eval $(python-package))

