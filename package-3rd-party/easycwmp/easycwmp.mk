################################################################################
#
# easycwmp
#
################################################################################
EASYCWMP_VERSION = 8a4c3f36d49cd85b33ebb8b9f05b448bcad85e51
EASYCWMP_SITE = $(call github,pivasoftware,easycwmp)
EASYCWMP_DEPENDENCIES = libcurl libubox ubus openssl libuci microxml

EASYCWMP_AUTORECONF = YES

EASYCWMP_CONF_ENV = \
	CFLAGS="$(TARGET_CFLAGS) -D_GNU_SOURCE" \
	LDFLAGS="$(TARGET_LDFLAGS) -Wl,-rpath-link=$(STAGING_DIR)/usr/lib"

EASYCWMP_CONF_OPTS += \
	--with-uci-include-path=$(STAGING_DIR)/usr/include \
	--with-libubox-include-path=$(STAGING_DIR)/usr/include \
	--with-libubus-include-path=$(STAGING_DIR)/usr/include

EASYCWMP_CONF_OPTS += \
	--enable-acs=multi

EASYCWMP_CONF_OPTS += \
	--enable-jsonc=1

define EASYCWMP_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/usr/sbin/easycwmp $(@D)/ext/openwrt/scripts/easycwmp.sh
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/usr/share/easycwmp $(@D)/ext/openwrt/scripts/defaults
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/usr/share/easycwmp/functions \
		$(@D)/ext/openwrt/scripts/functions/common/common \
		$(@D)/ext/openwrt/scripts/functions/common/device_info \
		$(@D)/ext/openwrt/scripts/functions/common/management_server \
		$(@D)/ext/openwrt/scripts/functions/common/ipping_launch \
		$(@D)/ext/openwrt/scripts/functions/tr098/root \
		$(@D)/ext/openwrt/scripts/functions/tr098/wan_device \
		$(@D)/ext/openwrt/scripts/functions/tr098/lan_device \
		$(@D)/ext/openwrt/scripts/functions/tr098/ipping_diagnostic \
		$(@D)/ext/openwrt/scripts/functions/laird/laird_device
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/etc/config/easycwmp $(@D)/ext/openwrt/config/easycwmp
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/usr/sbin $(@D)/bin/easycwmpd
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/lib $(@D)/ext/openwrt/scripts/functions/laird/functions.sh
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/lib/config $(@D)/ext/openwrt/scripts/functions/laird/uci.sh
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/lib/functions $(@D)/ext/openwrt/scripts/functions/laird/network.sh
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/etc/easycwmp $(@D)/ext/openwrt/init.d/easycwmpd
	$(INSTALL) -m 0755 -D -t $(TARGET_DIR)/etc/init.d $(EASYCWMP_PKGDIR)/S97easycwmp
endef

$(eval $(autotools-package))
