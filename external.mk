# Summit branch number, update for every branch
export BR2_SUMMIT_BRANCH := 13

export BR2_SUMMIT_BUILD_VERSION = $(if $(VERSION),$(VERSION),0.$(BR2_SUMMIT_BRANCH).0.0)
export SUMMIT_SOM_SW_DESCRIPTION = $(call qstrip,$(BR2_SUMMIT_SW_DESCRIPTION))

RFPROS_FILESHARE_AUTH ?= $(if $(RFPROS_FILESHARE_USER),$(RFPROS_FILESHARE_USER):$(RFPROS_FILESHARE_PASS)@,)

export SUMMIT_SOM_URI_BASE_ARCHIVE  ?= https://github.com/Ezurio/wb-package-archive/releases/download/LRD-REL
export SUMMIT_SOM_URI_BASE_INTERNAL ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux

# Package, 3rd-party package, and toolchain fragments.  The summit-key-provider
# host package (package/summit-key-provider/) is discovered here like any other
# package; it derives and exports the secure-boot signing variables
# (KEY_PATH / KEYS_DIR / LOCAL_KEYS_DIR and, for Cloud HSM HAB builds, a
# redirected SIG_DATA_PATH) and injects the U-Boot / TI R5 loader dependencies.
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/toolchain/*/*.mk))

# HAB / AHAB signing support.  These consume the variables derived and exported
# by summit-key-provider above (notably the redirected SIG_DATA_PATH for Cloud
# HSM HAB builds), so they must come after the wildcard include.

# HAB signing support: make host-cst a dependency of U-Boot and export
# SRK_TABLE/CSF_KEY/IMG_KEY so binman's nxp-imx8mcst etype can locate
# the HAB PKI tree during the U-Boot build.
ifeq ($(BR2_PACKAGE_HOST_CST),y)
UBOOT_DEPENDENCIES += host-cst

ifeq ($(SIG_DATA_PATH),)
$(error SIG_DATA_PATH is not set for HAB signing (BR2_SUMMIT_IMX_HAB=y))
endif

SRK_TABLE ?= $(SIG_DATA_PATH)/crts/SRK_1_2_3_4_table.bin
CSF_KEY ?= $(SIG_DATA_PATH)/crts/CSF1_1_sha256_2048_65537_v3_usr_crt.pem
IMG_KEY ?= $(SIG_DATA_PATH)/crts/IMG1_1_sha256_2048_65537_v3_usr_crt.pem

export SRK_TABLE CSF_KEY IMG_KEY
endif

# AHAB signing support: make host-python-spsdk a dependency of U-Boot and export
# SIG_DATA_PATH so the post-image script can locate the AHAB PKI tree
# when signing flash.bin after the U-Boot build.
ifeq ($(BR2_PACKAGE_HOST_PYTHON_SPSDK),y)
UBOOT_DEPENDENCIES += host-python-spsdk

SIG_DATA_PATH ?= $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/nitrogen/keys/ahab

export SIG_DATA_PATH
endif
