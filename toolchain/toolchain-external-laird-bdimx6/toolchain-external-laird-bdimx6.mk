################################################################################
#
# toolchain-external-laird-bdimx6
#
################################################################################

TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_VERSION = 11.0.0.178
TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_SOURCE = bdimx6_toolchain-laird-$(TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_VERSION).tar.gz

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_SITE = https://files.devops.rfpros.com/builds/linux/toolchain/$(TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_VERSION)
else
TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(TOOLCHAIN_EXTERNAL_LAIRD_BDIMX6_VERSION)
endif

$(eval $(toolchain-external-package))
