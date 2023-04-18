#####################################################################
# Summit Remote Control Manager (RCM)
#####################################################################

SUMMIT_RCM_VERSION = local
SUMMIT_RCM_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/summit-rcm
SUMMIT_RCM_SITE_METHOD = local
SUMMIT_RCM_SETUP_TYPE = setuptools
SUMMIT_RCM_DEPENDENCIES = openssl python3

ifeq ($(BR2_PACKAGE_HOST_PYTHON_CYTHON),y)
SUMMIT_RCM_DEPENDENCIES += host-python-cython
endif

SUMMIT_RCM_DEFAULT_USERNAME = $(call qstrip,$(BR2_PACKAGE_SUMMIT_RCM_DEFAULT_USERNAME))
SUMMIT_RCM_DEFAULT_PASSWORD = $(call qstrip,$(BR2_PACKAGE_SUMMIT_RCM_DEFAULT_PASSWORD))
SUMMIT_RCM_BIND_IP = $(call qstrip,$(BR2_PACKAGE_SUMMIT_RCM_BIND_IP))

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_AWM),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/awm
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_MODEM),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/modem
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_BLUETOOTH),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/bluetooth
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_HID),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/hid
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_VSP),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/vsp
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_ENABLE_STUNNEL_CONTROL),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/stunnel
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_IPTABLES_FIREWALL),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/iptables
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_RADIO_SISO_MODE),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/radio_siso_mode
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_CHRONY_NTP),y)
	SUMMIT_RCM_EXTRA_PACKAGES += summit_rcm/chrony
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_AT_INTERFACE),y)
	SUMMIT_RCM_EXTRA_PACKAGES += \
		summit_rcm/at_interface \
		summit_rcm/at_interface/commands
endif

SUMMIT_RCM_EXTRA_PACKAGES += \
	summit_rcm/services \
	summit_rcm/rest_api \
	summit_rcm/rest_api/system

SUMMIT_RCM_ENV = SUMMIT_RCM_EXTRA_PACKAGES='$(SUMMIT_RCM_EXTRA_PACKAGES)'

define SUMMIT_RCM_POST_INSTALL_TARGET_HOOK_CMDS
	$(INSTALL) -d $(TARGET_DIR)/etc/summit-rcm

	$(INSTALL) -D -t $(TARGET_DIR)/usr/bin/summit-rcm.scripts -m 755 $(@D)/*.sh
	$(INSTALL) -D -t $(TARGET_DIR)/etc -m 644 $(@D)/summit-rcm.ini

	$(SED) '/^default_/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a default_password: \"$(SUMMIT_RCM_DEFAULT_PASSWORD)\"' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a default_username: \"$(SUMMIT_RCM_DEFAULT_USERNAME)\"' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^managed_software_devices/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a managed_software_devices: $(BR2_PACKAGE_SUMMIT_RCM_MANAGED_SOFTWARE_DEVICES)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^unmanaged_hardware_devices/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a unmanaged_hardware_devices: $(BR2_PACKAGE_SUMMIT_RCM_UNMANAGED_HARDWARE_DEVICES)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^awm_cfg/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a awm_cfg:$(BR2_PACKAGE_ADAPTIVE_WW_BINARIES_CFG_FILE)' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^enable_allow_unauthenticated_reboot_reset/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a enable_allow_unauthenticated_reboot_reset: \
		$(if $(findstring y,$(BR2_PACKAGE_SUMMIT_RCM_UNAUTHENTICATED)),True,False)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^allow_multiple_user_sessions/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a allow_multiple_user_sessions: \
		$(if $(findstring y,$(BR2_PACKAGE_SUMMIT_RCM_ALLOW_MUTLIPLE_USER_SESSIONS)),True,False)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) 's,^tools.sessions.on:.*,tools.sessions.on: \
		$(if $(findstring y,$(BR2_PACKAGE_SUMMIT_RCM_ENABLE_SESSIONS)),True,False),' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^enable_client_auth/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a enable_client_auth: \
		$(if $(findstring y,$(BR2_PACKAGE_SUMMIT_RCM_ENABLE_CLIENT_AUTHENTICATION)),True,False)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(INSTALL) -d $(TARGET_DIR)/etc/nginx-unit/state/certs
	echo '{\
		"listeners":{\
			"$(SUMMIT_RCM_BIND_IP):443":{\
				"pass":"applications/summit-rcm",\
				"tls":{\
					"certificate":"summit-rcm-bundle"\
				}\
			}\
		},\
		"applications":{\
			"summit-rcm":{\
				"type":"python",\
				"path":"/lib/python$(PYTHON3_VERSION_MAJOR)/site-packages/summit_rcm",\
				"module":"summit_rcm",\
				"callable":"app"\
			}\
		}\
	}' > $(TARGET_DIR)/etc/nginx-unit/state/conf.json
endef

ifeq ($(BR2_PACKAGE_LRD_ENCRYPTED_STORAGE_TOOLKIT),y)
define SUMMIT_RCM_POST_INSTALL_TARGET_HOOK_CMDS2
	ln -sf /rodata/secret/summit-rcm/ssl/summit-rcm-bundle.pem $(TARGET_DIR)/etc/nginx-unit/state/certs/summit-rcm-bundle
endef
else
define SUMMIT_RCM_POST_INSTALL_TARGET_HOOK_CMDS2
	cat $(@D)/ssl/server.crt $(@D)/ssl/ca.crt $(@D)/ssl/server.key > $(TARGET_DIR)/etc/nginx-unit/state/certs/summit-rcm-bundle
endef
endif

SUMMIT_RCM_POST_INSTALL_TARGET_HOOKS += SUMMIT_RCM_POST_INSTALL_TARGET_HOOK_CMDS SUMMIT_RCM_POST_INSTALL_TARGET_HOOK_CMDS2

$(eval $(python-package))
