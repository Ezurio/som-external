################################################################################
# aws-kms-pkcs11
################################################################################
AWS_KMS_PKCS11_VERSION = 0.0.17
AWS_KMS_PKCS11_SITE = $(call github,JackOfMostTrades,aws-kms-pkcs11,v$(AWS_KMS_PKCS11_VERSION))
AWS_KMS_PKCS11_LICENSE = MIT
AWS_KMS_PKCS11_LICENSE_FILES = LICENSE

HOST_AWS_KMS_PKCS11_DEPENDENCIES += \
	host-aws-sdk-cpp \
	host-openssl \
	host-p11-kit \
	host-json-c \
	host-pkgconf \
	host-pkcs11-provider

HOST_AWS_KMS_PKCS11_ENV += \
	$(HOST_MAKE_ENV) \
	AWS_SDK_PATH=$(HOST_DIR) \
	AWS_SDK_LIB_PATH=$(HOST_DIR)/lib \
	LIBRARY_PATH=$(HOST_DIR)/lib

define HOST_AWS_KMS_PKCS11_BUILD_CMDS
	$(HOST_AWS_KMS_PKCS11_ENV) $(MAKE) -C $(@D) $(HOST_CONFIGURE_OPTS)
endef

define HOST_AWS_KMS_PKCS11_INSTALL_CMDS
	$(INSTALL) -D -m 0644 -t $(HOST_DIR)/lib/pkcs11 $(@D)/aws_kms_pkcs11.so
	$(INSTALL) -D -m 0644 -t $(HOST_DIR)/etc/ssl/openssl.cnf.d \
		$(AWS_KMS_PKCS11_PKGDIR)/pkcs11-aws-kms.cnf
	$(SED) 's|@@HOST_DIR@@|$(HOST_DIR)|g' \
		$(HOST_DIR)/etc/ssl/openssl.cnf.d/pkcs11-aws-kms.cnf
endef

$(eval $(host-generic-package))
