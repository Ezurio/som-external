################################################################################
# aws-kms-pkcs11
################################################################################
AWS_KMS_PKCS11_VERSION_MAJOR = 0
AWS_KMS_PKCS11_VERSION_MINOR = 0
AWS_KMS_PKCS11_VERSION_PATCH = 17
AWS_KMS_PKCS11_VERSION = v$(AWS_KMS_PKCS11_VERSION_MAJOR).$(AWS_KMS_PKCS11_VERSION_MINOR).$(AWS_KMS_PKCS11_VERSION_PATCH)
AWS_KMS_PKCS11_SITE_METHOD = git
AWS_KMS_PKCS11_SITE = https://github.com/JackOfMostTrades/aws-kms-pkcs11.git
HOST_AWS_KMS_PKCS11_DEPENDENCIES += \
	host-aws-sdk-cpp \
	host-openssl \
	host-p11-kit \
	host-json-c \
	host-libp11 \
	host-pkgconf \
	host-pkcs11-provider \
	host-python3 \
	host-python-asn1crypto
AWS_KMS_PKCS11_LICENSE = MIT
AWS_KMS_PKCS11_LICENSE_FILES = LICENSE
HOST_AWS_KMS_PKCS11_ENV += \
	AWS_SDK_PATH=$(HOST_DIR) \
	AWS_SDK_LIB_PATH=$(HOST_DIR)/lib \
	PKCS11_INC=-I$(HOST_DIR)/include/p11-kit-1/p11-kit \
	PKCS11_MOD_PATH=$(HOST_DIR)/lib/pkcs11 \
	JSON_C_INC=-I$(HOST_DIR)/include/json-c \
	LIBRARY_PATH="$(HOST_DIR)/lib:$(LIBRARY_PATH)"

define HOST_AWS_KMS_PKCS11_BUILD_CMDS
	$(HOST_MAKE_ENV) $(HOST_AWS_KMS_PKCS11_ENV) $(MAKE) -C $(@D) $(HOST_CONFIGURE_OPTS)
	mv $(@D)/aws_kms_pkcs11.so $(@D)/aws_kms_pkcs11.so.$(AWS_KMS_PKCS11_VERSION_MAJOR).$(AWS_KMS_PKCS11_VERSION_MINOR).$(AWS_KMS_PKCS11_VERSION_PATCH)
	ln -s aws_kms_pkcs11.so.$(AWS_KMS_PKCS11_VERSION_MAJOR).$(AWS_KMS_PKCS11_VERSION_MINOR).$(AWS_KMS_PKCS11_VERSION_PATCH) $(@D)/aws_kms_pkcs11.so.$(AWS_KMS_PKCS11_VERSION_MAJOR)
	ln -s aws_kms_pkcs11.so.$(AWS_KMS_PKCS11_VERSION_MAJOR) $(@D)/aws_kms_pkcs11.so
endef

ifeq ($(AWS_KMS_SIGNING),y)
ifeq ($(AWS_KMS_PKCS11_SLOT_LABEL),)
$(error AWS_KMS_PKCS11_SLOT_LABEL is not set for AWS_KMS_SIGNING=y)
endif
ifeq ($(AWS_KMS_PKCS11_KMS_KEY_ID),)
$(error AWS_KMS_PKCS11_KMS_KEY_ID is not set for AWS_KMS_SIGNING=y)
endif
ifeq ($(AWS_KMS_PKCS11_AWS_REGION),)
$(error AWS_KMS_PKCS11_AWS_REGION is not set for AWS_KMS_SIGNING=y)
endif
endif

define HOST_AWS_KMS_PKCS11_INSTALL_CMDS
	cp -P $(@D)/aws_kms_pkcs11.so* $(HOST_DIR)/lib/pkcs11/

	$(INSTALL) -m 0644 -t $(HOST_DIR) \
		$(HOST_AWS_KMS_PKCS11_PKGDIR)/aws-kms-pkcs11-config.json
	$(SED) 's|@@SLOT_LABEL@@|$(AWS_KMS_PKCS11_SLOT_LABEL)|g' \
		$(HOST_DIR)/aws-kms-pkcs11-config.json
	$(SED) 's|@@KMS_KEY_ID@@|$(AWS_KMS_PKCS11_KMS_KEY_ID)|g' \
		$(HOST_DIR)/aws-kms-pkcs11-config.json
	$(SED) 's|@@AWS_REGION@@|$(AWS_KMS_PKCS11_AWS_REGION)|g' \
		$(HOST_DIR)/aws-kms-pkcs11-config.json

	python3 $(HOST_DIR)/opt/pkcs11-provider/uri2pem.py --bypass --out "$(KEY_PATH)" "pkcs11:token=$(AWS_KMS_PKCS11_SLOT_LABEL);type=private"
endef

$(eval $(host-generic-package))
