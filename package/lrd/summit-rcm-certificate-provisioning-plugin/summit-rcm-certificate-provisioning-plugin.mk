#####################################################################
# Summit Remote Control Manager (RCM) Certificate Provisioning Plugin
#####################################################################

SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_VERSION = local
SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/summit-rcm/summit_rcm/plugins/provisioning
SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_SITE_METHOD = local
SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_SETUP_TYPE = setuptools
SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_DEPENDENCIES = python3 summit-rcm

ifeq ($(BR2_PACKAGE_HOST_PYTHON_CYTHON),y)
SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_DEPENDENCIES += host-python-cython
endif

SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_EXTRA_PACKAGES = \
	summit_rcm_provisioning \
	summit_rcm_provisioning/services \
	summit_rcm_provisioning/middleware

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_V2_ROUTES),y)
    SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_EXTRA_PACKAGES += summit_rcm_provisioning/rest_api/v2/system
endif

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_LEGACY_ROUTES),y)
    SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_EXTRA_PACKAGES += summit_rcm_provisioning/rest_api/legacy
endif

SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_ENV = SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_EXTRA_PACKAGES='$(SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_EXTRA_PACKAGES)'

define SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_POST_INSTALL_TARGET_HOOK_CMDS
	$(INSTALL) -D $(BR2_EXTERNAL_LRD_SOM_PATH)/board/configs-common/keys/rest-server/server.crt $(TARGET_DIR)/etc/summit-rcm/ssl/provisioning.crt
	$(INSTALL) -D $(BR2_EXTERNAL_LRD_SOM_PATH)/board/configs-common/keys/rest-server/server.key $(TARGET_DIR)/etc/summit-rcm/ssl/provisioning.key
	$(INSTALL) -D $(BR2_EXTERNAL_LRD_SOM_PATH)/board/configs-common/keys/rest-server/ca.crt $(TARGET_DIR)/etc/summit-rcm/ssl/provisioning.ca.crt
endef

SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_POST_INSTALL_TARGET_HOOKS += SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN_POST_INSTALL_TARGET_HOOK_CMDS

$(eval $(python-package))
