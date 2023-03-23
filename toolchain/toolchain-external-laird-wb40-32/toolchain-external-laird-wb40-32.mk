################################################################################
#
# toolchain-external-laird-wb40-32
#
################################################################################

TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_VERSION = 11.0.0.17
TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_SOURCE = wb40_32_toolchain-laird-$(TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_VERSION).tar.gz

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_SITE = https://files.devops.rfpros.com/builds/linux/toolchain/$(TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_VERSION)
else
TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(TOOLCHAIN_EXTERNAL_LAIRD_WB40_32_VERSION)
endif

$(eval $(toolchain-external-package))
