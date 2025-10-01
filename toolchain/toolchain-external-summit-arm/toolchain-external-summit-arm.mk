################################################################################
#
# toolchain-external-summit-arm
#
################################################################################

TOOLCHAIN_EXTERNAL_SUMMIT_RELEASE ?= https://github.com/Ezurio/summit_toolchain_release/releases/download/LRD-REL
TOOLCHAIN_EXTERNAL_SUMMIT_ARM_VERSION = $(call qstrip,$(BR2_TOOLCHAIN_EXTERNAL_SUMMIT_ARM_VERSION))
TOOLCHAIN_EXTERNAL_SUMMIT_ARM_SOURCE = $(call qstrip,$(BR2_TOOLCHAIN_EXTERNAL_SUMMIT_ARM_PREFIX)_toolchain-$(BR2_TOOLCHAIN_EXTERNAL_SUMMIT_ARM_ID)-$(TOOLCHAIN_EXTERNAL_SUMMIT_ARM_VERSION).tar.gz)

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
TOOLCHAIN_EXTERNAL_SUMMIT_ARM_SITE = $(SUMMIT_SOM_URI_BASE_INTERNAL)/toolchain/$(TOOLCHAIN_EXTERNAL_SUMMIT_ARM_VERSION)
else
TOOLCHAIN_EXTERNAL_SUMMIT_ARM_SITE = $(TOOLCHAIN_EXTERNAL_SUMMIT_RELEASE)-$(TOOLCHAIN_EXTERNAL_SUMMIT_ARM_VERSION)
endif

$(eval $(toolchain-external-package))
