#####################################################################
# Industrial Gateway igconfd
#####################################################################

IGCONFD_VERSION = local
IGCONFD_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/igconfd
IGCONFD_SITE_METHOD = local
IGCONFD_SETUP_TYPE = setuptools

define IGCONFD_INSTALL_INIT_SYSTEMD
        $(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/systemd/system \
		$(IGCONFD_PKGDIR)/igconfd.service
        $(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/dbus-1/system.d \
		$(IGCONFD_PKGDIR)/com.lairdtech.security.ConfigService.conf
endef

$(eval $(python-package))

