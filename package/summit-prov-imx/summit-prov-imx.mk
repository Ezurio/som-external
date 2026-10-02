#####################################################################
# Summit Provisioning Service for NXP i.MX 93
#####################################################################

SUMMIT_PROV_IMX_SITE = $(SUMMIT_PROV_IMX_PKGDIR)/files
SUMMIT_PROV_IMX_SITE_METHOD = local
SUMMIT_PROV_IMX_LICENSE = Ezurio
SUMMIT_PROV_IMX_LICENSE_FILES = LICENSE.ezurio
SUMMIT_PROV_IMX_DEPENDENCIES = imx-secure-enclave

SUMMIT_PROV_IMX_DATADIR = /usr/share/summit-prov-imx

# SIG_DATA_PATH and SPSDK_AHAB_SIGNER are set in external.mk, which is
# parsed after this file, so they are only referenced in recipe commands.
# external.mk only sets SIG_DATA_PATH for AHAB builds, so fall back to the
# same default for the prov_data of non-secure builds.
SUMMIT_PROV_IMX_SIG_DATA_PATH = \
	$(or $(SIG_DATA_PATH),$(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/nitrogen/keys/ahab)

SUMMIT_PROV_IMX_GENERATE_ENV = \
	$(HOST_MAKE_ENV) \
	SECURE="$(BR2_SUMMIT_IMX_AHAB)" \
	SIG_DATA_PATH="$(SUMMIT_PROV_IMX_SIG_DATA_PATH)"

ifeq ($(BR2_SUMMIT_IMX_AHAB),y)
# Secure builds use ELE to unwrap the fleet key and decrypt an AES-GCM
# payload. A fixed issue date avoids SPSDK's host-clock default so the signed
# key-exchange message is reproducible.
SUMMIT_PROV_IMX_DEPENDENCIES += \
	host-python3 \
	host-python-cryptography \
	host-python-pyyaml \
	host-python-spsdk
SUMMIT_PROV_IMX_ARTIFACTS = \
	key-exchange.bin \
	oem-ka-public.bin \
	key-import-tlv.bin \
	prov-data.tar.gz.aes-gcm \
	SHA256SUMS
SUMMIT_PROV_IMX_GENERATE_ENV += \
	PYTHON="$(HOST_DIR)/bin/python3" \
	FAMILY="$(call qstrip,$(BR2_SUMMIT_IMX_AHAB_FAMILY))" \
	ISSUE_DATE=2026-08 \
	SIGNER="$(SPSDK_AHAB_SIGNER)" \
	HSM_PKCS11_LIBRARY="$(HSM_PKCS11_LIBRARY)"

# With a Cloud HSM AHAB key the key-exchange message is signed through the
# backend's PKCS#11 module instead of the local SRK key.
ifneq ($(HSM_AHAB_KEY_ID),)
SUMMIT_PROV_IMX_DEPENDENCIES += host-summit-key-provider $(HSM_HOST_DEPENDENCIES)
SUMMIT_PROV_IMX_GENERATE_ENV += $(HSM_MAKE_OPTS)
endif

define SUMMIT_PROV_IMX_INSTALL_WRAPPER
	$(INSTALL) -D -m 0755 $(@D)/summit-prov-imx.sh \
		$(TARGET_DIR)/usr/sbin/summit-prov-imx.sh
endef
else
# Non-secure builds decrypt an AES-CBC payload with a per-build key stored in
# the wrapper script. This is for evaluation only and does not protect
# prov_data.
SUMMIT_PROV_IMX_DEPENDENCIES += host-openssl
SUMMIT_PROV_IMX_ARTIFACTS = \
	prov-data.tar.gz.aes-cbc \
	SHA256SUMS

define SUMMIT_PROV_IMX_INSTALL_WRAPPER
	$(INSTALL) -D -m 0700 $(@D)/generated/summit-prov-imx.sh \
		$(TARGET_DIR)/usr/sbin/summit-prov-imx.sh
endef
endif

define SUMMIT_PROV_IMX_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) -Wall -Wextra -Werror -DPSA_COMPLIANT \
		$(@D)/summit-prov-imx.c $(TARGET_LDFLAGS) -lele_hsm \
		-o $(@D)/summit-prov-imx
	$(SUMMIT_PROV_IMX_GENERATE_ENV) \
		$(SUMMIT_PROV_IMX_PKGDIR)/generate-artifacts.sh \
		$(@D) $(@D)/generated
endef

define SUMMIT_PROV_IMX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/summit-prov-imx \
		$(TARGET_DIR)/usr/sbin/summit-prov-imx
	$(SUMMIT_PROV_IMX_INSTALL_WRAPPER)
	for f in $(SUMMIT_PROV_IMX_ARTIFACTS); do \
		$(INSTALL) -D -m 0644 $(@D)/generated/$$f \
			$(TARGET_DIR)$(SUMMIT_PROV_IMX_DATADIR)/$$f || exit 1; \
	done
endef

define SUMMIT_PROV_IMX_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/summit-prov-imx.service \
		$(TARGET_DIR)/usr/lib/systemd/system/summit-prov-imx.service
endef

$(eval $(generic-package))
