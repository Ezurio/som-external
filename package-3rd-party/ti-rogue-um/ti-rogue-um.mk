################################################################################
#
# ti-rogue-um
#
################################################################################

# This corresponds to SDK 10.01.10
TI_ROGUE_UM_VERSION = ba93a3e38c683ccb03a7cf8f2e7dffe2f9cbcf1c
TI_ROGUE_UM_SITE = https://git.ti.com/cgit/graphics/ti-img-rogue-umlibs/snapshot
TI_ROGUE_UM_SOURCE = ti-img-rogue-umlibs-$(TI_ROGUE_UM_VERSION).tar.xz
TI_ROGUE_UM_LICENSE = TI TSPA License
TI_ROGUE_UM_LICENSE_FILES = LICENSE
TI_ROGUE_UM_PROVIDES = libgles powervr

define TI_ROGUE_UM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		DESTDIR=$(TARGET_DIR) \
		TARGET_PRODUCT=$(BR2_TARGET_TI_ROGUE_UM_TARGET_PRODUCT) \
		install
endef

$(eval $(generic-package))
