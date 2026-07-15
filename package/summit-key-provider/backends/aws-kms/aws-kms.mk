# AWS KMS backend for Cloud HSM signing
#
# User-facing variables (set on command line or environment):
#   AWS_KMS_KEY_ARN         — umbrella ARN, used as default for all roles
#   AWS_KMS_CSF_KEY_ARN     — HAB CSF signing key
#   AWS_KMS_IMG_KEY_ARN     — HAB IMG signing key
#   AWS_KMS_FIT_KEY_ARN     — FIT image signing key
#   AWS_KMS_AHAB_KEY_ARN    — AHAB container signing key (i.MX9)
#
# This fragment maps the AWS-specific variables into generic HSM_* names
# consumed by summit-key-provider.sh and the rest of the build system.

# Role-specific ARNs default to the umbrella ARN.
AWS_KMS_CSF_KEY_ARN ?= $(AWS_KMS_KEY_ARN)
AWS_KMS_IMG_KEY_ARN ?= $(AWS_KMS_KEY_ARN)
AWS_KMS_FIT_KEY_ARN ?= $(AWS_KMS_KEY_ARN)

# Derive the signing flag from the presence of any ARN.
CLOUD_HSM_SIGNING := $(if $(strip $(or $(AWS_KMS_KEY_ARN),$(AWS_KMS_CSF_KEY_ARN),$(AWS_KMS_IMG_KEY_ARN),$(AWS_KMS_FIT_KEY_ARN))),y)

# Map to generic key IDs used by summit-key-provider.sh
HSM_KEY_ID     := $(AWS_KMS_KEY_ARN)
HSM_CSF_KEY_ID := $(AWS_KMS_CSF_KEY_ARN)
HSM_IMG_KEY_ID := $(AWS_KMS_IMG_KEY_ARN)
HSM_FIT_KEY_ID := $(AWS_KMS_FIT_KEY_ARN)

# Host packages required by this backend
HSM_HOST_DEPENDENCIES = host-pkcs11-provider host-aws-kms-pkcs11

# Make opts and environment for the PKCS#11 module
HSM_MAKE_OPTS = \
	OPENSSL_CONF=$(HOST_DIR)/host_pkcs11config.cnf \
	AWS_KMS_PKCS11_CONFIG=$(HOST_DIR)/aws-kms-pkcs11-config.json

# (Re)generate the multi-slot PKCS#11 config from the ARN variables.
# Invoked by the host-summit-key-provider build step (HOST_SUMMIT_KEY_PROVIDER
# _BUILD_CMDS) so that a single `host-summit-key-provider-rebuild` regenerates
# the config alongside the key wrappers.  Generating it here — rather than at
# host-aws-kms-pkcs11 install time, which is stamp-cached — avoids the config
# going stale when the ARN set changes.
define HSM_GEN_CONFIG_CMD
	$(HOST_DIR)/bin/python3 \
		$(SUMMIT_KEY_PROVIDER_PKGDIR)/backends/aws-kms/aws_kms_config.py \
		$(HOST_DIR)/aws-kms-pkcs11-config.json
endef

# Export the ARN variables so aws_kms_config.py (invoked from the
# host-summit-key-provider build step) can read them from the environment.
# AWS_KMS_KEY_ARN and AWS_KMS_AHAB_KEY_ARN are command-line origin (already
# auto-exported by make) but are listed here explicitly for clarity/robustness.
export AWS_KMS_KEY_ARN AWS_KMS_CSF_KEY_ARN AWS_KMS_IMG_KEY_ARN
export AWS_KMS_FIT_KEY_ARN AWS_KMS_AHAB_KEY_ARN
export AWS_KMS_PKCS11_CONFIG = $(HOST_DIR)/aws-kms-pkcs11-config.json
