################################################################################
#
# ti-mcu-plus-sdk
#
################################################################################

TI_MCU_PLUS_SDK_VERSION = 11.02.00.23
TI_MCU_PLUS_SDK_NAME = mcu_plus_sdk_am62x_$(subst .,_,$(TI_MCU_PLUS_SDK_VERSION))
TI_MCU_PLUS_SDK_SOURCE = $(TI_MCU_PLUS_SDK_NAME)-linux-x64-installer.run
TI_MCU_PLUS_SDK_SITE = https://dr-download.ti.com/software-development/software-development-kit-sdk/MD-IIN1zFBAlS/$(TI_MCU_PLUS_SDK_VERSION)
TI_MCU_PLUS_SDK_LICENSE = BSD-3-Clause MIT TI-Commercial-License
TI_MCU_PLUS_SDK_LICENSE_FILES = docs/mcu_plus_sdk_am62x_manifest.html

define HOST_TI_MCU_PLUS_SDK_EXTRACT_CMDS
	cp $(HOST_TI_MCU_PLUS_SDK_DL_DIR)/$(TI_MCU_PLUS_SDK_SOURCE) $(@D)/
	chmod +x $(@D)/$(TI_MCU_PLUS_SDK_SOURCE)
	$(@D)/$(TI_MCU_PLUS_SDK_SOURCE) --prefix $(@D) --mode unattended
endef

TI_MCU_PLUS_SDK_INSTALL_PREFIX = $(HOST_DIR)/opt
TI_MCU_PLUS_SDK_INSTALLDIR = \
	$(TI_MCU_PLUS_SDK_INSTALL_PREFIX)/$(TI_MCU_PLUS_SDK_NAME)

define HOST_TI_MCU_PLUS_SDK_INSTALL_CMDS
	rm -rf $(TI_MCU_PLUS_SDK_INSTALLDIR)
	mkdir -p $(TI_MCU_PLUS_SDK_INSTALL_PREFIX)
	cp -af $(@D)/$(TI_MCU_PLUS_SDK_NAME) $(TI_MCU_PLUS_SDK_INSTALL_PREFIX)/
endef

$(eval $(host-generic-package))
