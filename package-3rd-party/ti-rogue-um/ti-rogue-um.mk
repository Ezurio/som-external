################################################################################
#
# ti-rogue-um
#
################################################################################

# 24.2.6643903
TI_ROGUE_UM_VERSION = 630f1d5b2be896d3040c927a9fd0d16aaeb33d02
TI_ROGUE_UM_SITE = $(call github,TexasInstruments,ti-img-rogue-umlibs,$(TI_ROGUE_UM_VERSION))
TI_ROGUE_UM_LICENSE = TI TSPA License
TI_ROGUE_UM_LICENSE_FILES = LICENSE
TI_ROGUE_UM_PROVIDES = powervr

TI_ROGUE_UM_PVR_BUILD = release
TI_ROGUE_UM_PVR_WS = lws-generic

TI_ROGUE_UM_SRC = targetfs/$(call qstrip,$(BR2_TARGET_TI_ROGUE_UM_TARGET_PRODUCT))/$(TI_ROGUE_UM_PVR_WS)/$(TI_ROGUE_UM_PVR_BUILD)/

ifeq ($(BR2_PACKAGE_TI_ROGUE_UM_TOOLS),y)
define TI_ROGUE_UM_INSTALL_TOOLS_CMDS
	rsync -rlptDWK --no-perms --inplace --include "usr/bin/" --exclude "*" \
		$(@D)/$(TI_ROGUE_UM_SRC) $(TARGET_DIR)
endef
endif

define TI_ROGUE_UM_INSTALL_TARGET_CMDS
	$(TI_ROGUE_UM_INSTALL_TOOLS_CMDS)

	rsync -rlptDWK --no-perms --inplace --exclude "usr/bin/" \
		$(@D)/$(TI_ROGUE_UM_SRC) $(TARGET_DIR)
endef

$(eval $(generic-package))
