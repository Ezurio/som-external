#####################################################################
# Summit Remote Control Manager (RCM) Modem Plugin
#####################################################################

SUMMIT_RCM_MODEM_PLUGIN_VERSION = local
SUMMIT_RCM_MODEM_PLUGIN_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/summit-rcm/summit_rcm/plugins/modem
SUMMIT_RCM_MODEM_PLUGIN_SITE_METHOD = local
SUMMIT_RCM_MODEM_PLUGIN_SETUP_TYPE = setuptools
SUMMIT_RCM_MODEM_PLUGIN_DEPENDENCIES = python3 summit-rcm

ifeq ($(BR2_PACKAGE_HOST_PYTHON_CYTHON),y)
SUMMIT_RCM_MODEM_PLUGIN_DEPENDENCIES += host-python-cython
endif

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_REST_API_LEGACY_ROUTES),y)
    SUMMIT_RCM_MODEM_PLUGIN_EXTRA_PACKAGES = \
    summit_rcm_modem \
    summit_rcm_modem/rest_api/legacy
endif

SUMMIT_RCM_MODEM_PLUGIN_ENV = SUMMIT_RCM_MODEM_PLUGIN_EXTRA_PACKAGES='$(SUMMIT_RCM_MODEM_PLUGIN_EXTRA_PACKAGES)'

$(eval $(python-package))
