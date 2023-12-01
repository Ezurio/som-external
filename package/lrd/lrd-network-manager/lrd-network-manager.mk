################################################################################
#
# Summit network-manager
#
################################################################################

LRD_NETWORK_MANAGER_INSTALL_STAGING = YES
LRD_NETWORK_MANAGER_LICENSE = GPL-2.0+ (app), LGPL-2.1+ (libnm)
LRD_NETWORK_MANAGER_LICENSE_FILES = COPYING COPYING.LGPL CONTRIBUTING.md
LRD_NETWORK_MANAGER_CPE_ID_VENDOR = gnome
LRD_NETWORK_MANAGER_CPE_ID_PRODUCT = networkmanager
LRD_NETWORK_MANAGER_SELINUX_MODULES = networkmanager
LRD_NETWORK_MANAGER_CVE_PRODUCT = networkmanager
LRD_NETWORK_MANAGER_CVE_VERSION = 1.42.8

ifeq ($(BR2_LRD_DEVEL_BUILD),)
ifneq ($(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE),)

LRD_NETWORK_MANAGER_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
LRD_NETWORK_MANAGER_SOURCE = lrd-network-manager-src-$(LRD_NETWORK_MANAGER_VERSION).tar.xz
ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
  LRD_NETWORK_MANAGER_SITE = https://files.devops.rfpros.com/builds/linux/lrd-network-manager/src/$(LRD_NETWORK_MANAGER_VERSION)
else
  LRD_NETWORK_MANAGER_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(LRD_NETWORK_MANAGER_VERSION)
endif

endif
endif

ifeq ($(LRD_NETWORK_MANAGER_VERSION),)

LRD_NETWORK_MANAGER_VERSION = local
LRD_NETWORK_MANAGER_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/lrd-network-manager
LRD_NETWORK_MANAGER_SITE_METHOD = local

endif

LRD_NETWORK_MANAGER_DEPENDENCIES = \
	host-pkgconf \
	dbus \
	libglib2 \
	libndp \
	udev \
	util-linux \
	openssl

LRD_NETWORK_MANAGER_CONF_OPTS = \
	-Ddocs=false \
	-Dtests=no \
	-Dqt=false \
	-Diptables=/usr/sbin/iptables \
	-Difupdown=false \
	-Difcfg_rh=false \
	-Dnm_cloud_setup=false \
	-Dsession_tracking_consolekit=false \
	-Dwext=false \
	-Dcrypto=openssl

ifeq ($(BR2_PACKAGE_AUDIT),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += audit
LRD_NETWORK_MANAGER_CONF_OPTS += -Dlibaudit=yes
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dlibaudit=no
endif

ifeq ($(BR2_PACKAGE_DHCP_CLIENT),y)
LRD_NETWORK_MANAGER_CONF_OPTS += -Ddhclient=/sbin/dhclient
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Ddhclient=no
endif

ifeq ($(BR2_PACKAGE_DHCPCD),y)
LRD_NETWORK_MANAGER_CONF_OPTS += -Ddhcpcd=/sbin/dhcpcd
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Ddhcpcd=no
endif

ifeq ($(BR2_PACKAGE_IWD),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += iwd
LRD_NETWORK_MANAGER_CONF_OPTS += -Diwd=true
ifeq ($(BR2_PACKAGE_WPA_SUPPLICANT),y)
LRD_NETWORK_MANAGER_CONF_OPTS += -Dconfig_wifi_backend_default=wpa_supplicant
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dconfig_wifi_backend_default=iwd
endif
else
LRD_NETWORK_MANAGER_CONF_OPTS += \
	-Diwd=false \
	-Dconfig_wifi_backend_default=wpa_supplicant
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_CONCHECK),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += libcurl
LRD_NETWORK_MANAGER_CONF_OPTS += -Dconcheck=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dconcheck=false
endif

ifeq ($(BR2_PACKAGE_LIBPSL),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += libpsl
LRD_NETWORK_MANAGER_CONF_OPTS += -Dlibpsl=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dlibpsl=false
endif

ifeq ($(BR2_PACKAGE_LIBSELINUX),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += libselinux
LRD_NETWORK_MANAGER_CONF_OPTS += -Dselinux=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dselinux=false
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_MODEM_MANAGER),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += modem-manager mobile-broadband-provider-info
LRD_NETWORK_MANAGER_CONF_OPTS += -Dmodem_manager=true

ifeq ($(BR2_PACKAGE_OFONO),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += ofono
LRD_NETWORK_MANAGER_CONF_OPTS += -Dofono=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dofono=false
endif

ifeq ($(BR2_PACKAGE_BLUEZ5_UTILS),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += bluez5_utils
LRD_NETWORK_MANAGER_CONF_OPTS += -Dbluez5_dun=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dbluez5_dun=false
endif

else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dmodem_manager=false -Dofono=false -Dbluez5_dun=false
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_OVS),y)
LRD_NETWORK_MANAGER_CONF_OPTS += -Dovs=true
LRD_NETWORK_MANAGER_DEPENDENCIES += jansson
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dovs=false
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_PPPD),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += pppd
LRD_NETWORK_MANAGER_CONF_OPTS += \
	-Dppp=true \
	-Dpppd=/usr/sbin/pppd \
	-Dpppd_plugin_dir=/usr/lib/pppd/$(PPPD_VERSION)
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dppp=false
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_TUI),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += newt
LRD_NETWORK_MANAGER_CONF_OPTS += -Dnmtui=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dnmtui=false
endif

ifeq ($(BR2_PACKAGE_SYSTEMD),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += systemd
LRD_NETWORK_MANAGER_CONF_OPTS += \
	-Dsystemd_journal=true \
	-Dconfig_logging_backend_default=journal \
	-Dsession_tracking=systemd \
	-Dsuspend_resume=systemd
else
LRD_NETWORK_MANAGER_CONF_OPTS += \
	-Dsystemd_journal=false \
	-Dconfig_logging_backend_default=syslog \
	-Dsession_tracking=no \
	-Dsuspend_resume=upower \
	-Dsystemdsystemunitdir=no
endif

ifeq ($(BR2_PACKAGE_POLKIT),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += polkit
LRD_NETWORK_MANAGER_CONF_OPTS += -Dpolkit=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dpolkit=false
endif

ifeq ($(BR2_PACKAGE_LRD_NETWORK_MANAGER_CLI),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += readline
LRD_NETWORK_MANAGER_CONF_OPTS += -Dnmcli=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dnmcli=false
endif

ifeq ($(BR2_PACKAGE_GOBJECT_INTROSPECTION),y)
LRD_NETWORK_MANAGER_DEPENDENCIES += gobject-introspection
LRD_NETWORK_MANAGER_CONF_OPTS += -Dintrospection=true
else
LRD_NETWORK_MANAGER_CONF_OPTS += -Dintrospection=false
endif

define LRD_NETWORK_MANAGER_INSTALL_INIT_SYSV
	$(INSTALL) -m 0755 -D $(LRD_NETWORK_MANAGER_PKGDIR)/S45network-manager \
		$(TARGET_DIR)/etc/init.d/S45network-manager
endef

define LRD_NETWORK_MANAGER_INSTALL_INIT_SYSTEMD
	ln -sf /usr/lib/systemd/system/NetworkManager.service \
		$(TARGET_DIR)/etc/systemd/system/dbus-org.freedesktop.NetworkManager.service

	$(SED) 's,--no-daemon,--no-daemon --state-file=/etc/NetworkManager/NetworkManager.state,' \
		$(TARGET_DIR)/usr/lib/systemd/system/NetworkManager.service
endef

# create directories that may not be populated on certain builds
define LRD_NETWORK_MANAGER_CREATE_EMPTY_DIRS
	mkdir -p $(TARGET_DIR)/etc/NetworkManager/certs
	mkdir -p $(TARGET_DIR)/etc/NetworkManager/system-connections
endef

LRD_NETWORK_MANAGER_TARGET_FINALIZE_HOOKS += LRD_NETWORK_MANAGER_CREATE_EMPTY_DIRS

$(eval $(meson-package))
