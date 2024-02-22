#####################################################################
# Summit Remote Control Manager (RCM) Adaptive Worldwide Mode (AWM) Plugin
#####################################################################

SUMMIT_RCM_AWM_PLUGIN_VERSION = local
SUMMIT_RCM_AWM_PLUGIN_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/summit-rcm/summit_rcm/plugins/awm
SUMMIT_RCM_AWM_PLUGIN_SITE_METHOD = local
SUMMIT_RCM_AWM_PLUGIN_SETUP_TYPE = setuptools
SUMMIT_RCM_AWM_PLUGIN_DEPENDENCIES = python3 summit-rcm

ifeq ($(BR2_PACKAGE_HOST_PYTHON_CYTHON),y)
SUMMIT_RCM_AWM_PLUGIN_DEPENDENCIES += host-python-cython
endif

SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES = \
	summit_rcm_awm \
	summit_rcm_awm/services

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_AT_INTERFACE),y)
	SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES += summit_rcm_awm/at_interface/commands
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_V2_ROUTES),y)
    SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES += summit_rcm_awm/rest_api/v2/network
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_LEGACY_ROUTES),y)
    SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES += summit_rcm_awm/rest_api/legacy
endif

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_DOCS),y)
	SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES += summit_rcm_awm/rest_api/utils/spectree
	SUMMIT_RCM_AWM_PLUGIN_DEPENDENCIES += host-summit-rcm-awm-plugin
	HOST_SUMMIT_RCM_AWM_PLUGIN_DEPENDENCIES += \
		host-summit-rcm \
		host-python3 \
		host-python-falcon \
		host-python-spectree \
		host-python-pydantic \
		host-python-typing-extensions
	HOST_SUMMIT_RCM_AWM_PLUGIN_ENV = \
		DOCS_GENERATION='True' \
		OPENAPI_JSON_PATH='$(TARGET_DIR)/summit-rcm-openapi-awm-plugin.json' \
		SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES='$(SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES)'
endif

SUMMIT_RCM_AWM_PLUGIN_ENV = SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES='$(SUMMIT_RCM_AWM_PLUGIN_EXTRA_PACKAGES)'

define SUMMIT_RCM_AWM_PLUGIN_POST_INSTALL_TARGET_HOOK_CMDS
    $(INSTALL) -d $(TARGET_DIR)/etc
    echo -e "[summit-rcm]\nawm_cfg: \"${BR2_PACKAGE_ADAPTIVE_WW_BINARIES_CFG_FILE}\"" > $(TARGET_DIR)/etc/summit-rcm-awm.ini
endef

SUMMIT_RCM_AWM_PLUGIN_POST_INSTALL_TARGET_HOOKS += SUMMIT_RCM_AWM_PLUGIN_POST_INSTALL_TARGET_HOOK_CMDS

$(eval $(python-package))
$(eval $(host-python-package))
