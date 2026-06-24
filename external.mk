# Summit branch number, update for every branch
export BR2_SUMMIT_BRANCH := 14

export BR2_SUMMIT_BUILD_VERSION = $(if $(VERSION),$(VERSION),0.$(BR2_SUMMIT_BRANCH).0.0)
export SUMMIT_SOM_SW_DESCRIPTION = $(call qstrip,$(BR2_SUMMIT_SW_DESCRIPTION))

RFPROS_FILESHARE_AUTH ?= $(if $(RFPROS_FILESHARE_USER),$(RFPROS_FILESHARE_USER):$(RFPROS_FILESHARE_PASS)@,)

export SUMMIT_SOM_URI_BASE_ARCHIVE  ?= https://github.com/Ezurio/wb-package-archive/releases/download/LRD-REL
export SUMMIT_SOM_URI_BASE_INTERNAL ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux

ifeq ($(KEY_PATH),)
ifeq ($(AWS_KMS_SIGNING),)
ifneq ($(SECURE_TARGET_BUILD),)
$(error KEY_PATH is not set for secure target build)
endif
endif

ifneq ($(AWS_KMS_SIGNING),)
KEY_PATH = $(HOST_DIR)/dev_pkcs11.pem
else ifneq ($(findstring am6,$(BR2_ROOTFS_POST_SCRIPT_ARGS)),)
KEY_PATH = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/carbon/keys/dev.key
else
KEY_PATH = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/dev.key
endif
endif

ifeq ($(AWS_KMS_SIGNING),)
ifeq ($(wildcard $(KEY_PATH)),)
$(error Key file not found: $(KEY_PATH))
endif
KEYS_DIR = $(dir $(KEY_PATH))
else
ifeq ($(AWS_KMS_SIGNING_PKCS11_PUBLIC_CERT_PATH),)
$(error AWS_KMS_SIGNING_PKCS11_PUBLIC_CERT_PATH is not set for AWS_KMS_SIGNING=y)
endif
KEYS_DIR = $(dir $(AWS_KMS_SIGNING_PKCS11_PUBLIC_CERT_PATH))
endif

ifeq ($(wildcard $(KEYS_DIR)),)
$(error Keys directory not found: $(KEYS_DIR))
endif

export KEY_PATH KEYS_DIR

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

include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/toolchain/*/*.mk))
