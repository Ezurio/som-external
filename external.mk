# Summit branch number, update for every branch
export BR2_SUMMIT_BRANCH := 14

export BR2_SUMMIT_BUILD_VERSION = $(if $(VERSION),$(VERSION),0.$(BR2_SUMMIT_BRANCH).0.0)
export SUMMIT_SOM_SW_DESCRIPTION = $(call qstrip,$(BR2_SUMMIT_SW_DESCRIPTION))

RFPROS_FILESHARE_AUTH ?= $(if $(RFPROS_FILESHARE_USER),$(RFPROS_FILESHARE_USER):$(RFPROS_FILESHARE_PASS)@,)

export SUMMIT_SOM_URI_BASE_ARCHIVE  ?= https://github.com/Ezurio/wb-package-archive/releases/download/LRD-REL
export SUMMIT_SOM_URI_BASE_INTERNAL ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux

# Package, 3rd-party package, and toolchain fragments.  The summit-key-provider
# host package (package/summit-key-provider/) is discovered here like any other
# package; it derives and exports the secure-boot signing variables
# (SIG_SUPPORT_PATH / SIG_KEY_PATH / KEYS_DIR) and injects the U-Boot / TI R5
# loader dependencies.
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/toolchain/*/*.mk))

# HAB / AHAB signing support.  These consume the variables derived and exported
# by summit-key-provider above, so they must come after the wildcard include.

ifeq ($(BR2_PACKAGE_HOST_PYTHON_SPSDK),y)
UBOOT_DEPENDENCIES += host-python-spsdk
$(UBOOT_TARGET_CONFIGURE): | host-python-spsdk
endif

# HAB4 (i.MX8M): export the explicit SPSDK signing inputs consumed by binman's
# nxp-imx8mspsdk etype during the U-Boot build.
ifeq ($(BR2_SUMMIT_IMX_HAB),y)
SPSDK_HAB_SRK_TABLE ?= $(SIG_SUPPORT_PATH)/crts/SRK_1_2_3_4_table.bin
SPSDK_HAB_CSF_CERT ?= $(SIG_SUPPORT_PATH)/crts/CSF1_1_sha256_2048_65537_v3_usr_crt.pem
SPSDK_HAB_IMG_CERT ?= $(SIG_SUPPORT_PATH)/crts/IMG1_1_sha256_2048_65537_v3_usr_crt.pem
SPSDK_HAB_CSF_SIGNER ?= type=file;file_path=$(SIG_KEY_PATH)/CSF1_1_sha256_2048_65537_v3_usr_key.pem;password-file=$(SIG_KEY_PATH)/key_pass.txt;password-index=0
SPSDK_HAB_IMG_SIGNER ?= type=file;file_path=$(SIG_KEY_PATH)/IMG1_1_sha256_2048_65537_v3_usr_key.pem;password-file=$(SIG_KEY_PATH)/key_pass.txt;password-index=1

ifneq ($(CLOUD_HSM_SIGNING),)
SPSDK_HAB_CSF_TOKEN_LABEL := $(shell printf '%s' '$(HSM_CSF_KEY_ID)' | sed 's|.*/||' | cut -c1-32)
SPSDK_HAB_IMG_TOKEN_LABEL := $(shell printf '%s' '$(HSM_IMG_KEY_ID)' | sed 's|.*/||' | cut -c1-32)
SPSDK_HAB_CSF_SIGNER = type=pkcs11;so_path=$(HSM_PKCS11_LIBRARY);token_label=$(SPSDK_HAB_CSF_TOKEN_LABEL);key_label=$(notdir $(HSM_CSF_KEY_ID));user_pin=unused;$(HSM_SPSDK_PKCS11_OPTIONS)
SPSDK_HAB_IMG_SIGNER = type=pkcs11;so_path=$(HSM_PKCS11_LIBRARY);token_label=$(SPSDK_HAB_IMG_TOKEN_LABEL);key_label=$(notdir $(HSM_IMG_KEY_ID));user_pin=unused;$(HSM_SPSDK_PKCS11_OPTIONS)
endif

export SPSDK_HAB_SRK_TABLE SPSDK_HAB_CSF_CERT SPSDK_HAB_IMG_CERT
export SPSDK_HAB_CSF_SIGNER SPSDK_HAB_IMG_SIGNER
endif

# AHAB (i.MX9x): the post-image script signs flash.bin after the U-Boot build.
ifeq ($(BR2_SUMMIT_IMX_AHAB),y)
# Cloud HSM: sign AHAB containers (flash.bin in post_image_secure.sh and the
# summit-prov-imx key-exchange message) through the backend's PKCS#11 module.
# The certificates in SIG_SUPPORT_PATH are still used; the KMS key must be an
# ECC_NIST_P256 key matching the SRK certificate selected by used_srk_id.
ifneq ($(CLOUD_HSM_SIGNING),)
# The token label is the key ID truncated to 32 characters. The key ID comes
# from the environment, so single quotes are escaped before the shell call.
SPSDK_AHAB_KEY_LABEL := $(notdir $(HSM_AHAB_KEY_ID))
SPSDK_AHAB_TOKEN_LABEL := $(shell printf '%.32s' '$(subst ','\'',$(SPSDK_AHAB_KEY_LABEL))')
SPSDK_AHAB_SIGNER = type=pkcs11;so_path=$(HSM_PKCS11_LIBRARY);token_label=$(SPSDK_AHAB_TOKEN_LABEL);key_label=$(SPSDK_AHAB_KEY_LABEL);user_pin=unused
export SPSDK_AHAB_SIGNER
endif

ifeq ($(BR2_SUMMIT_IMX_AHAB_AUTO_LOCK),y)
UBOOT_KCONFIG_FIXUP_CMDS += $(call KCONFIG_ENABLE_OPT,CONFIG_SUMMIT_AHAB_AUTO_LOCK)
else
UBOOT_KCONFIG_FIXUP_CMDS += $(call KCONFIG_DISABLE_OPT,CONFIG_SUMMIT_AHAB_AUTO_LOCK)
endif
endif
