################################################################################
#
# summit-fips-toolchain
#
################################################################################

SUMMIT_FIPS_TOOLCHAIN_VERSION = 11.0.0.298
SUMMIT_FIPS_TOOLCHAIN_RELEASE ?= https://github.com/Ezurio/summit_toolchain_release/releases/download/LRD-REL
SUMMIT_FIPS_TOOLCHAIN_SOURCE = $(call qstrip,$(BR2_SUMMIT_FIPS_TOOLCHAIN_PREFIX))-$(HOSTARCH)_toolchain-laird-$(SUMMIT_FIPS_TOOLCHAIN_VERSION).tar.gz

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
SUMMIT_FIPS_TOOLCHAIN_SITE = $(SUMMIT_SOM_URI_BASE_INTERNAL)/toolchain/$(SUMMIT_FIPS_TOOLCHAIN_VERSION)
else
SUMMIT_FIPS_TOOLCHAIN_SITE = $(SUMMIT_FIPS_TOOLCHAIN_RELEASE)-$(SUMMIT_FIPS_TOOLCHAIN_VERSION)
endif

HOST_SUMMIT_FIPS_TOOLCHAIN_INSTALL_DIR = $(HOST_DIR)/opt/summit-fips-toolchain

define HOST_SUMMIT_FIPS_TOOLCHAIN_INSTALL_CMDS
	rm -rf $(HOST_SUMMIT_FIPS_TOOLCHAIN_INSTALL_DIR)
	mkdir -p $(HOST_SUMMIT_FIPS_TOOLCHAIN_INSTALL_DIR)
	cp -rf $(@D)/* $(HOST_SUMMIT_FIPS_TOOLCHAIN_INSTALL_DIR)/
endef

$(eval $(host-generic-package))
