################################################################################
#
# summit-key-provider (host package)
#
# Secure-boot signing key provisioning.  Owns:
#   - Cloud HSM backend auto-detection and variable mapping (backends/<name>/)
#   - KEY_PATH / KEYS_DIR / LOCAL_KEYS_DIR / SIG_DATA_PATH derivation
#   - the SECURE_TARGET_BUILD safety check
#   - make-opts injection for U-Boot / TI K3 R5 loader signing
#   - the host package that materializes KEYS_DIR (local key copy and/or
#     PKCS#11 HSM wrappers) and stages the HAB (i.MX8M) SIG_DATA_PATH tree
#
# The materialization runs once, as the host-summit-key-provider build step.
# U-Boot and the TI K3 R5 loader depend on it, so the keys are in place before
# any signing step (during the U-Boot build and at the post-image rebuild).
# Changing the signing keys/ARNs therefore requires a manual rebuild:
#   make host-summit-key-provider-rebuild uboot-rebuild ti-k3-r5-loader-rebuild
#
# external.mk discovers this file via its package/*/*.mk wildcard, ahead of the
# HAB / AHAB signing blocks that consume the derived, exported variables —
# including the redirected SIG_DATA_PATH.  The include guard keeps that single
# wildcard inclusion idempotent.
#
################################################################################

ifndef SUMMIT_KEY_PROVIDER_MK
SUMMIT_KEY_PROVIDER_MK := 1

SUMMIT_KEY_PROVIDER_PKGDIR = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/summit-key-provider

# ─── Cloud HSM backend auto-detection and mapping ───────────────────────────────
# Users set backend-specific variables (e.g. AWS_KMS_*_ARN); the backend is
# auto-detected from these, or set explicitly via CLOUD_HSM_BACKEND.
CLOUD_HSM_BACKEND ?=
ifeq ($(CLOUD_HSM_BACKEND),)
ifneq ($(strip $(or $(AWS_KMS_KEY_ARN),$(AWS_KMS_CSF_KEY_ARN),$(AWS_KMS_IMG_KEY_ARN),$(AWS_KMS_FIT_KEY_ARN))),)
CLOUD_HSM_BACKEND := aws-kms
endif
endif

ifneq ($(CLOUD_HSM_BACKEND),)
include $(SUMMIT_KEY_PROVIDER_PKGDIR)/backends/$(CLOUD_HSM_BACKEND)/$(CLOUD_HSM_BACKEND).mk
endif

# Optional backend hook: command to (re)generate any HSM PKCS#11 config as part
# of the host-summit-key-provider build.  Defaults to empty for local (non-HSM)
# builds and backends that need no config generation.
HSM_GEN_CONFIG_CMD ?=

export CLOUD_HSM_SIGNING CLOUD_HSM_BACKEND
export HSM_KEY_ID HSM_CSF_KEY_ID HSM_IMG_KEY_ID HSM_FIT_KEY_ID

# ─── Platform selector ──────────────────────────────────────────────────────────
ifneq ($(findstring am6,$(BR2_ROOTFS_POST_SCRIPT_ARGS)),)
SUMMIT_KEY_PROVIDER_PLATFORM := am6
endif
export SUMMIT_KEY_PROVIDER_PLATFORM

# ─── Local (source) keys directory ──────────────────────────────────────────────
# Directory of platform key material that materialization copies from:
# the user's KEY_PATH directory, or the per-platform default.
SUMMIT_KEY_PROVIDER_USER_KEY_PATH := $(KEY_PATH)
ifeq ($(LOCAL_KEYS_DIR),)
ifneq ($(SUMMIT_KEY_PROVIDER_USER_KEY_PATH),)
LOCAL_KEYS_DIR := $(dir $(SUMMIT_KEY_PROVIDER_USER_KEY_PATH))
else ifeq ($(SUMMIT_KEY_PROVIDER_PLATFORM),am6)
LOCAL_KEYS_DIR := $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/carbon/keys/
else
LOCAL_KEYS_DIR := $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/
endif
endif

# A secure *target* build must not silently fall back to the shared dev keys.
# Require one of:
#   - an explicit KEY_PATH,
#   - a Cloud HSM backend, or
#   - a HAB (host-cst) / AHAB (host-python-spsdk) signing anchor.
# On i.MX the root of trust is the HAB/AHAB PKI under SIG_DATA_PATH (the SRK
# hash is fused into the SoC), so when that anchor is configured the FIT "dev"
# key is allowed to default to the board key.
ifeq ($(SUMMIT_KEY_PROVIDER_USER_KEY_PATH),)
ifneq ($(SECURE_TARGET_BUILD),)
ifeq ($(CLOUD_HSM_SIGNING),)
ifneq ($(BR2_PACKAGE_HOST_CST),y)
ifneq ($(BR2_PACKAGE_HOST_PYTHON_SPSDK),y)
$(error KEY_PATH is not set for secure target build (set KEY_PATH, a Cloud HSM backend, or SIG_DATA_PATH for a HAB/AHAB build))
endif
endif
endif
endif
endif

# ─── Materialized (output) keys directory ───────────────────────────────────────
# Assembled by the host-summit-key-provider build step (summit-key-provider.sh).
# All consumers use these paths and stay agnostic to whether the underlying keys
# are local files or PKCS#11 HSM wrappers.  KEY_PATH points at the "dev" FIT
# signing key.
SUMMIT_KEY_PROVIDER_KEYS_DIR = $(BUILD_DIR)/summit-key-provider/keys
KEYS_DIR = $(SUMMIT_KEY_PROVIDER_KEYS_DIR)
KEY_PATH = $(SUMMIT_KEY_PROVIDER_KEYS_DIR)/dev.key
export KEY_PATH KEYS_DIR LOCAL_KEYS_DIR

# ─── HAB (i.MX8M) SIG_DATA_PATH staging for Cloud HSM ────────────────────────────
# For HSM builds, redirect SIG_DATA_PATH to a staging tree that the host
# package build step (below) populates with crts/ and PKCS#11 CSF/IMG wrappers.
# For local HAB builds SIG_DATA_PATH is left untouched (the host-cst block in external.mk validates
# and defaults it).
ifeq ($(BR2_PACKAGE_HOST_CST),y)
ifneq ($(CLOUD_HSM_SIGNING),)
ifndef SIG_DATA_PATH_ORIG
SIG_DATA_PATH_ORIG := $(SIG_DATA_PATH)
endif
ifeq ($(SIG_DATA_PATH_ORIG),)
$(error SIG_DATA_PATH is not set for HAB signing (BR2_SUMMIT_IMX_HAB=y))
endif
SIG_DATA_PATH = $(BUILD_DIR)/summit-key-provider/sig-data
SUMMIT_KEY_PROVIDER_STAGE_HAB := y
export SIG_DATA_PATH SIG_DATA_PATH_ORIG SUMMIT_KEY_PROVIDER_STAGE_HAB
endif
endif

# ─── Cloud HSM signing make-opts for U-Boot / TI K3 R5 loader ────────────────────
# This file is wildcard-included by external.mk after boot/uboot/uboot.mk and
# boot/ti-k3-r5-loader/ti-k3-r5-loader.mk, so we append the backend make-opts
# here for them to take effect.  The host tooling itself is pulled in
# transitively via the host-summit-key-provider dependency below.
ifneq ($(CLOUD_HSM_SIGNING),)
UBOOT_MAKE_OPTS += $(HSM_MAKE_OPTS)
TI_K3_R5_LOADER_MAKE_OPTS += $(HSM_MAKE_OPTS)
export OPENSSL_CONF = $(HOST_DIR)/host_pkcs11config.cnf
endif

# ─── host-summit-key-provider dependency ─────────────────────────────────────────
# U-Boot embeds the FIT public key and (on i.MX HAB) signs via binman during
# its own build, and the TI K3 R5 loader / U-Boot are re-signed at post-image;
# all of these need KEYS_DIR (and the staged SIG_DATA_PATH) materialized first.
# Making them depend on the host package guarantees that ordering.
#
# Note: external.mk includes this file after boot/uboot/uboot.mk and
# boot/ti-k3-r5-loader/ti-k3-r5-loader.mk have already run
# $(eval $(generic-package)).  That eval fixed each package's order-only
# configure prerequisite from a snapshot of *_FINAL_DEPENDENCIES
# (pkg-generic.mk: "$(2)_TARGET_CONFIGURE: | $(2)_FINAL_DEPENDENCIES)"), so the
# late "+=" below is honored for the per-package host rsync (evaluated in the
# .stamp_configured recipe) but NOT for build ordering.  Without an explicit
# prerequisite, U-Boot/R5 can configure — and rsync host-summit-key-provider's
# per-package host tree — before that package has been built (it is queued
# behind the slow host-aws-kms-pkcs11), which fails the rsync.  Add the
# order-only prerequisite on the configure stamps explicitly to close that gap.
ifeq ($(BR2_PACKAGE_HOST_SUMMIT_KEY_PROVIDER),y)
UBOOT_DEPENDENCIES += host-summit-key-provider
TI_K3_R5_LOADER_DEPENDENCIES += host-summit-key-provider
$(UBOOT_TARGET_CONFIGURE): | host-summit-key-provider
$(TI_K3_R5_LOADER_TARGET_CONFIGURE): | host-summit-key-provider
endif

# ─── host package: materialize KEYS_DIR (and stage HAB SIG_DATA_PATH) ────────────
# Source-less package: the "build" step assembles the keys directory from the
# local platform key material and, for Cloud HSM builds, overlays PKCS#11
# wrappers/certs.  For HSM HAB (i.MX8M) it also stages the SIG_DATA_PATH tree
# that binman consumes during the U-Boot build.
HOST_SUMMIT_KEY_PROVIDER_VERSION = 1.0
HOST_SUMMIT_KEY_PROVIDER_SITE = $(SUMMIT_KEY_PROVIDER_PKGDIR)
HOST_SUMMIT_KEY_PROVIDER_SITE_METHOD = local
HOST_SUMMIT_KEY_PROVIDER_LICENSE = LicenseRef-Ezurio-Clause

# HSM materialization needs the PKCS#11 host tooling plus OpenSSL and Python
# (uri2pem.py wrapper generation and self-signed cert creation).
ifneq ($(CLOUD_HSM_SIGNING),)
HOST_SUMMIT_KEY_PROVIDER_DEPENDENCIES += \
	host-openssl host-python3 $(HSM_HOST_DEPENDENCIES)
endif

# Common environment passed to the materialization helper.
SUMMIT_KEY_PROVIDER_ENV = \
	HOST_DIR="$(HOST_DIR)" \
	KEYS_DIR="$(KEYS_DIR)" \
	LOCAL_KEYS_DIR="$(LOCAL_KEYS_DIR)" \
	CLOUD_HSM_SIGNING="$(CLOUD_HSM_SIGNING)" \
	CLOUD_HSM_BACKEND="$(CLOUD_HSM_BACKEND)" \
	HSM_KEY_ID="$(HSM_KEY_ID)" HSM_CSF_KEY_ID="$(HSM_CSF_KEY_ID)" \
	HSM_IMG_KEY_ID="$(HSM_IMG_KEY_ID)" HSM_FIT_KEY_ID="$(HSM_FIT_KEY_ID)" \
	SUMMIT_KEY_PROVIDER_PLATFORM="$(SUMMIT_KEY_PROVIDER_PLATFORM)" \
	OPENSSL_CONF="$(OPENSSL_CONF)" \
	AWS_KMS_PKCS11_CONFIG="$(AWS_KMS_PKCS11_CONFIG)"

# HAB (i.MX8M) Cloud HSM: stage the SIG_DATA_PATH tree after materializing.
SUMMIT_KEY_PROVIDER_STAGE_HAB_CMD =
ifeq ($(SUMMIT_KEY_PROVIDER_STAGE_HAB),y)
define SUMMIT_KEY_PROVIDER_STAGE_HAB_CMD
	$(SUMMIT_KEY_PROVIDER_ENV) \
	SIG_DATA_PATH="$(SIG_DATA_PATH)" SIG_DATA_PATH_ORIG="$(SIG_DATA_PATH_ORIG)" \
	CSF_KEY="$(CSF_KEY)" IMG_KEY="$(IMG_KEY)" \
		$(SUMMIT_KEY_PROVIDER_PKGDIR)/summit-key-provider.sh stage-hab
endef
endif

define HOST_SUMMIT_KEY_PROVIDER_BUILD_CMDS
	$(HSM_GEN_CONFIG_CMD)
	$(SUMMIT_KEY_PROVIDER_ENV) \
		$(SUMMIT_KEY_PROVIDER_PKGDIR)/summit-key-provider.sh materialize
	$(SUMMIT_KEY_PROVIDER_STAGE_HAB_CMD)
endef

# host-generic-package derives pkgname/pkgdir from $(lastword $(MAKEFILE_LIST)).
# The backend include above appended backends/<name>/<name>.mk to MAKEFILE_LIST,
# which would otherwise mis-name this package (e.g. host-aws-kms with empty build
# commands).  Pin the identity for the eval, then restore Buildroot's standard
# (MAKEFILE_LIST-based) definitions so later package .mk files resolve correctly.
pkgdir := $(SUMMIT_KEY_PROVIDER_PKGDIR)
pkgname := summit-key-provider
$(eval $(host-generic-package))
pkgdir = $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST))))
pkgname = $(lastword $(subst /, ,$(pkgdir)))

endif # SUMMIT_KEY_PROVIDER_MK
