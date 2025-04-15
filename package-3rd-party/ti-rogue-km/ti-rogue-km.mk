################################################################################
#
# ti-rogue-km
#
################################################################################

# 24.2.6643903
TI_ROGUE_KM_VERSION = 8eaff654a8871118c08cfafe53795f57e3b6b396
TI_ROGUE_KM_SITE = https://git.ti.com/cgit/graphics/ti-img-rogue-driver/snapshot
TI_ROGUE_KM_SOURCE = ti-img-rogue-driver-$(TI_ROGUE_KM_VERSION).tar.xz
TI_ROGUE_KM_LICENSE = MIT or GPL-2.0
TI_ROGUE_KM_LICENSE_FILES = README

TI_ROGUE_KM_DEPENDENCIES = linux

TI_ROGUE_KM_PVR_BUILD = release
TI_ROGUE_KM_PVR_WS = lws-generic
TI_ROGUE_KM_TARGET_PRODUCT = $(call qstrip,$(BR2_TARGET_TI_ROGUE_KM_TARGET_PRODUCT))

TI_ROGUE_KM_MAKE_OPTS = \
	$(LINUX_MAKE_FLAGS) \
	KERNELDIR=$(LINUX_DIR) \
	BUILD=$(TI_ROGUE_KM_PVR_BUILD) \
	PVR_BUILD_DIR=$(TI_ROGUE_KM_TARGET_PRODUCT) \
	WINDOW_SYSTEM=$(TI_ROGUE_KM_PVR_WS)

define TI_ROGUE_KM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) $(TI_ROGUE_KM_MAKE_OPTS)
endef

define TI_ROGUE_KM_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(LINUX_DIR) \
		M=$(@D)/binary_$(TI_ROGUE_KM_TARGET_PRODUCT)_$(TI_ROGUE_KM_PVR_WS)_$(TI_ROGUE_KM_PVR_BUILD)/target_aarch64/kbuild \
		INSTALL_MOD_PATH=$(TARGET_DIR) \
		modules_install
endef

$(eval $(generic-package))
