################################################################################
#
# toolchain-external-laird-component
#
################################################################################

TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_VERSION = 3.0.0.4
TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_PREFIX = $(call qstrip,$(BR2_TOOLCHAIN_EXTERNAL_PREFIX))
TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_SOURCE = $(TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_PREFIX)-$(TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_VERSION).tar.xz

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_SITE = https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/toolchains/$(TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_PREFIX)/$(TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_VERSION)
else
TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(TOOLCHAIN_EXTERNAL_LAIRD_COMPONENT_VERSION)
endif

$(eval $(toolchain-external-package))
