#############################################################
#
# FIPS Check Utility
#
#############################################################

FIPSCHECK_VERSION = local
FIPSCHECK_SITE = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/fipscheck
FIPSCHECK_SITE_METHOD = local
FIPSCHECK_LICENSE = MIT
FIPSCHECK_LICENSE_FILES = COPYING

FIPSCHECK_DEPENDENCIES += openssl host-pkgconf
FIPSCHECK_AUTORECONF = YES

ifeq ($(BR2_TOOLCHAIN_EXTERNAL_LAIRD_ARM_7),y)
# this is need to prevent enabling code hardenning options, that were not enabled
# on lrd-7 builds and not included in hash calculation
ifeq ($(BR2_ARM_CPU_ARMV7A),y)
FIPSCHECK_CONF_ENV = CFLAGS+=" -fno-stack-protector -U_FORTIFY_SOURCE -D__UBOOT__ -marm -O3"
else
FIPSCHECK_CONF_ENV = CFLAGS+=" -fno-stack-protector -U_FORTIFY_SOURCE -D__UBOOT__ -marm"
endif
FIPSCHECK_MAKE_OPTS = LDFLAGS+="-XCClinker -D__UBOOT__ "
endif

HOST_FIPSCHECK_DEPENDENCIES += host-openssl host-pkgconf
HOST_FIPSCHECK_AUTORECONF = YES

$(eval $(autotools-package))
$(eval $(host-autotools-package))
