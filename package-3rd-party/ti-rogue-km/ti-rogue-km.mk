################################################################################
#
# ti-rogue-km
#
################################################################################

# This corresponds to SDK 10.01.10
TI_ROGUE_KM_VERSION = 0884dea56e6b9fd59bcc6beba40a089b7161d70d
TI_ROGUE_KM_SITE = https://git.ti.com/cgit/graphics/ti-img-rogue-driver/snapshot
TI_ROGUE_KM_SOURCE = ti-img-rogue-driver-$(TI_ROGUE_KM_VERSION).tar.xz
TI_ROGUE_KM_LICENSE = MIT or GPL-2.0
TI_ROGUE_KM_LICENSE_FILES = README

TI_ROGUE_KM_DEPENDENCIES = linux

TI_ROGUE_KM_PVR_BUILD = "release"
TI_ROGUE_KM_PVR_WS = "wayland"

TI_ROGUE_KM_MAKE_OPTS = \
	$(LINUX_MAKE_FLAGS) \
	KERNELDIR=$(LINUX_DIR) \
	BUILD=$(TI_ROGUE_KM_PVR_BUILD) \
	PVR_BUILD_DIR=$(BR2_TARGET_TI_ROGUE_KM_TARGET_PRODUCT) \
	WINDOW_SYSTEM=$(TI_ROGUE_KM_PVR_WS)

define TI_ROGUE_KM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TI_ROGUE_KM_MAKE_OPTS)
endef

define TI_ROGUE_KM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(LINUX_DIR) \
		M=$(@D)/binary_$(BR2_TARGET_TI_ROGUE_KM_TARGET_PRODUCT)_$(TI_ROGUE_KM_PVR_WS)_$(TI_ROGUE_KM_PVR_BUILD)/target_aarch64/kbuild \
		INSTALL_MOD_PATH=$(TARGET_DIR) \
		modules_install
endef

$(eval $(generic-package))
