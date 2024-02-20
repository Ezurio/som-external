#############################################################
#
# SDC Supplicant
#
#############################################################
ifneq ($(BR2_LRD_NO_RADIO)$(BR2_LRD_DEVEL_BUILD),)
# development build, or non-development rdvk using local/latest source
SDCSUPP_VERSION = local
# note, the summit supplicant git repository will always be closed source
SDCSUPP_SITE = $(BR2_EXTERNAL_LRD_CLOSED_SOURCE_PATH)/package/externals/wpa_supplicant
SDCSUPP_SITE_METHOD = local
else
SDCSUPP_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
SDCSUPP_SOURCE = summit_supplicant-src-$(SDCSUPP_VERSION).tar.gz
ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
SDCSUPP_SITE = https://files.devops.rfpros.com/builds/linux/summit_supplicant/laird/$(SDCSUPP_VERSION)
else
SDCSUPP_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(SDCSUPP_VERSION)
endif

endif

SDCSUPP_LICENSE = BSD-3-Clause

SDCSUPP_DEPENDENCIES = host-pkgconf libnl openssl
ifneq ($(SDCSUPP_VERSION),local)
SDCSUPP_DEPENDENCIES += summit-supplicant-binaries
endif

ifneq ($(BR2_PACKAGE_OPENSSL_FIPS),)
SDCSUPP_FIPS = CONFIG_FIPS=y
ifeq ($(BR2_PACKAGE_LAIRD_OPENSSL_FIPS),y)
SDCSUPP_FIPS += CONFIG_FIPS_LAIRD=y
endif
else
ifeq ($(BR2_PACKAGE_SUMMITSSL_FIPS_BINARIES),y)
SDCSUPP_FIPS = CONFIG_FIPS=y
SDCSUPP_FIPS += CONFIG_FIPS_LAIRD=y
endif
endif

ifeq ($(BR2_PACKAGE_LIBOPENSSL_3_0),y)
ifeq ($(BR2_PACKAGE_LIBOPENSSL_ENABLE_FIPS),y)
SDCSUPP_FIPS = CONFIG_FIPS=y
SDCSUPP_FIPS += CONFIG_FIPS_LAIRD=y
endif
endif

ifeq ($(BR2_PACKAGE_SDCSUPP_LEGACY),y)
ifeq ($(SDCSUPP_VERSION),local)
	SDCSUPP_DEPENDENCIES += sdcsdk
endif
	SDCSUPP_CONFIG = $(@D)/wpa_supplicant/config_legacy
else
	SDCSUPP_DEPENDENCIES += dbus
	SDCSUPP_CONFIG = $(@D)/wpa_supplicant/config_openssl
endif

define SDCSUPP_BUILD_CMDS
	cp $(SDCSUPP_CONFIG) $(@D)/wpa_supplicant/.config
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) $(MAKE) -C $(@D)/wpa_supplicant BINDIR=/usr/sbin $(SDCSUPP_FIPS)
	$(TARGET_OBJCOPY) $(@D)/wpa_supplicant/wpa_supplicant $(@D)/wpa_supplicant/sdcsupp
endef

ifeq ($(BR2_PACKAGE_SDCSUPP_WPA_CLI),y)
define SDCSUPP_INSTALL_WPA_CLI
	$(INSTALL) -D -m 755 $(@D)/wpa_supplicant/wpa_cli $(TARGET_DIR)/usr/sbin/wpa_cli
endef
endif

ifeq ($(BR2_PACKAGE_SDCSUPP_WPA_PASSPHRASE),y)
define SDCSUPP_INSTALL_WPA_PASSPHRASE
	$(INSTALL) -D -m 755 $(@D)/wpa_supplicant/wpa_passphrase $(TARGET_DIR)/usr/bin/wpa_passphrase
endef
endif

ifneq ($(BR2_PACKAGE_SDCSUPP_LEGACY),y)

ifeq ($(BR2_PACKAGE_WPA_SUPPLICANT),y)
	# both wpa_supplicant and sdcsupp installed, postfix to avoid collision
	SDCSUPP_DBUS_SERVICE_POSTFIX = .summit
else
	# only sdcsupp installed, no postfix needed
	SDCSUPP_DBUS_SERVICE_POSTFIX =
endif

define SDCSUPP_INSTALL_DBUS
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/dbus/dbus-wpa_supplicant.conf \
		$(TARGET_DIR)/etc/dbus-1/system.d/wpa_supplicant.conf
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/dbus/fi.w1.wpa_supplicant1.service \
		$(TARGET_DIR)/usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service$(SDCSUPP_DBUS_SERVICE_POSTFIX)
endef

define SDCSUPP_INSTALL_WPA_CLIENT_SO
	$(INSTALL) -m 0644 -D $(@D)/$(WPA_SUPPLICANT_SUBDIR)/libwpa_client.so \
		$(TARGET_DIR)/usr/lib/libwpa_client.so
endef

define SDCSUPP_INSTALL_STAGING_WPA_CLIENT_SO
	$(INSTALL) -m 0644 -D $(@D)/$(WPA_SUPPLICANT_SUBDIR)/libwpa_client.so \
		$(STAGING_DIR)/usr/lib/libwpa_client.so
	$(INSTALL) -m 0644 -D $(@D)/src/common/wpa_ctrl.h \
		$(STAGING_DIR)/usr/include/wpa_ctrl.h
endef

endif

ifeq ($(SDCSUPP_VERSION),local)
define SDCSUPP_INSTALL_SDCSUPP_SO
	$(INSTALL) -m 0755 -D $(@D)/$(WPA_SUPPLICANT_SUBDIR)/libsdcsupp.so \
		$(TARGET_DIR)/usr/lib/libsdcsupp.so
endef

define SDCSUPP_INSTALL_STAGING_SDCSUPP_SO
	$(INSTALL) -m 0755 -D $(@D)/$(WPA_SUPPLICANT_SUBDIR)/libsdcsupp.so \
		$(STAGING_DIR)/usr/lib/libsdcsupp.so
endef
endif

ifeq ($(BR2_PACKAGE_SDCSUPP_LIBS_ONLY),y)

define SDCSUPP_INSTALL_STAGING_CMDS
	$(SDCSUPP_INSTALL_STAGING_SDCSUPP_SO)
endef

define SDCSUPP_INSTALL_TARGET_CMDS
	$(SDCSUPP_INSTALL_SDCSUPP_SO)
endef

else
SDCSUPP_INSTALL_STAGING = YES

define SDCSUPP_INSTALL_STAGING_CMDS
	$(SDCSUPP_INSTALL_STAGING_WPA_CLIENT_SO)
	$(SDCSUPP_INSTALL_STAGING_SDCSUPP_SO)
endef

define SDCSUPP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/wpa_supplicant/sdcsupp $(TARGET_DIR)/usr/sbin/sdcsupp
	$(SDCSUPP_INSTALL_WPA_CLI)
	$(SDCSUPP_INSTALL_WPA_PASSPHRASE)
	$(SDCSUPP_INSTALL_DBUS)
	$(SDCSUPP_INSTALL_WPA_CLIENT_SO)
	$(SDCSUPP_INSTALL_SDCSUPP_SO)
endef

define SDCSUPP_INSTALL_INIT_SYSTEMD
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/systemd/wpa_supplicant.service \
		$(TARGET_DIR)/usr/lib/systemd/system/wpa_supplicant.service
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/systemd/wpa_supplicant@.service \
		$(TARGET_DIR)/usr/lib/systemd/system/wpa_supplicant@.service
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/systemd/wpa_supplicant-nl80211@.service \
		$(TARGET_DIR)/usr/lib/systemd/system/wpa_supplicant-nl80211@.service
	$(INSTALL) -m 0644 -D $(@D)/wpa_supplicant/systemd/wpa_supplicant-wired@.service \
		$(TARGET_DIR)/usr/lib/systemd/system/wpa_supplicant-wired@.service
	$(INSTALL) -m 0644 -D $(SDCSUPP_PKGDIR)/50-wpa_supplicant.preset \
		$(TARGET_DIR)/usr/lib/systemd/system-preset/50-wpa_supplicant.preset
endef

endif

$(eval $(generic-package))
