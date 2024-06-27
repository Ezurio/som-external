################################################################################
#
# toolchain-external-laird-arm
#
################################################################################

TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION = $(call qstrip,$(BR2_TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION))
ifeq ($(BR2_ARM_EABIHF),y)
TOOLCHAIN_EXTERNAL_LAIRD_ARM_SOURCE = som60_toolchain-laird-$(TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION).tar.gz
else
TOOLCHAIN_EXTERNAL_LAIRD_ARM_SOURCE = wb4x_toolchain-laird-$(TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION).tar.gz
endif

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
TOOLCHAIN_EXTERNAL_LAIRD_ARM_SITE = https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux/toolchain/$(TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION)
else
TOOLCHAIN_EXTERNAL_LAIRD_ARM_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(TOOLCHAIN_EXTERNAL_LAIRD_ARM_VERSION)
endif

$(eval $(toolchain-external-package))
