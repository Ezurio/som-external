#####################################################################
# Summit Remote Control Manager (RCM) Unauthenticated Plugin
#####################################################################

SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_VERSION = local
SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/summit-rcm/summit_rcm/plugins/unauthenticated
SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_SITE_METHOD = local
SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_SETUP_TYPE = setuptools
SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_DEPENDENCIES = python3 summit-rcm

ifeq ($(BR2_PACKAGE_HOST_PYTHON_CYTHON),y)
SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_DEPENDENCIES += host-python-cython
endif

SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_EXTRA_PACKAGES = \
	summit_rcm_unauthenticated \
	summit_rcm_unauthenticated/services

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_V2_ROUTES),y)
    SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_EXTRA_PACKAGES += summit_rcm_unauthenticated/rest_api/v2/system
endif
ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_LEGACY_ROUTES),y)
    SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_EXTRA_PACKAGES += summit_rcm_unauthenticated/rest_api/legacy
endif

SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_ENV = SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_EXTRA_PACKAGES='$(SUMMIT_RCM_UNAUTHENTICATED_PLUGIN_EXTRA_PACKAGES)'

$(eval $(python-package))
