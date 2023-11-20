#############################################################
#
# Summit hostapd
#
#############################################################
ifneq ($(BR2_LRD_NO_RADIO)$(BR2_LRD_DEVEL_BUILD),)
# development build, or non-development rdvk using local/latest source
SUMMIT_HOSTAPD_VERSION = local
# note, the summit supplicant git repository will always be closed source
SUMMIT_HOSTAPD_SITE = $(BR2_EXTERNAL_LRD_CLOSED_SOURCE_PATH)/package/externals/wpa_supplicant
SUMMIT_HOSTAPD_SITE_METHOD = local
else
SUMMIT_HOSTAPD_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
SUMMIT_HOSTAPD_SOURCE = summit_supplicant-src-$(SUMMIT_HOSTAPD_VERSION).tar.gz
ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
SUMMIT_HOSTAPD_SITE = https://files.devops.rfpros.com/builds/linux/summit_supplicant/laird/$(SUMMIT_HOSTAPD_VERSION)
else
SUMMIT_HOSTAPD_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(SUMMIT_HOSTAPD_VERSION)
endif

endif

SUMMIT_HOSTAPD_LICENSE = BSD-3-Clause
SUMMIT_HOSTAPD_DEPENDENCIES = host-pkgconf libnl openssl

SUMMIT_HOSTAPD_CONFIG = $(@D)/hostapd/config_openssl

define SUMMIT_HOSTAPD_BUILD_CMDS
	cp $(SUMMIT_HOSTAPD_CONFIG) $(@D)/hostapd/.config
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D)/hostapd
endef

ifeq ($(BR2_PACKAGE_SUMMIT_HOSTAPD_HOSTAPD_CLI),y)
define SUMMIT_HOSTAPD_INSTALL_HOSTAPD_CLI
	$(INSTALL) -D -m 755 $(@D)/hostapd/hostapd_cli $(TARGET_DIR)/usr/sbin/hostapd_cli
endef
endif

define SUMMIT_HOSTAPD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/hostapd/hostapd $(TARGET_DIR)/usr/sbin/hostapd
	$(SUMMIT_HOSTAPD_INSTALL_HOSTAPD_CLI)
endef

$(eval $(generic-package))
