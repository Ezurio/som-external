################################################################################
# aws-kms-pkcs11
################################################################################
AWS_KMS_PKCS11_VERSION = 0.0.17
AWS_KMS_PKCS11_SITE = $(call github,JackOfMostTrades,aws-kms-pkcs11,v$(AWS_KMS_PKCS11_VERSION))
AWS_KMS_PKCS11_LICENSE = MIT
AWS_KMS_PKCS11_LICENSE_FILES = LICENSE
AWS_KMS_PKCS11_PKGDIR = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/aws-kms-pkcs11

AWS_KMS_PKCS11_DEPENDENCIES = \
	aws-sdk-cpp \
	openssl \
	json-c \
	libcurl \
	p11-kit \
	pkgconf \
	zlib

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

AWS_KMS_PKCS11_ENV += \
	$(TARGET_MAKE_ENV) \
	AWS_SDK_PATH=$(STAGING_DIR)/usr \
	AWS_SDK_LIB_PATH=$(STAGING_DIR)/usr/lib \
	LIBRARY_PATH=$(STAGING_DIR)/usr/lib

define HOST_AWS_KMS_PKCS11_BUILD_CMDS
	$(HOST_AWS_KMS_PKCS11_ENV) $(MAKE) -C $(@D) $(HOST_CONFIGURE_OPTS)
endef

define AWS_KMS_PKCS11_BUILD_CMDS
	$(AWS_KMS_PKCS11_ENV) $(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS)
endef

define HOST_AWS_KMS_PKCS11_INSTALL_CMDS
	$(INSTALL) -D -m 0644 -t $(HOST_DIR)/usr/lib/pkcs11 $(@D)/aws_kms_pkcs11.so
	$(INSTALL) -D -m 0644 -t $(HOST_DIR)/etc/ssl/openssl.cnf.d \
		$(AWS_KMS_PKCS11_PKGDIR)/pkcs11-aws-kms.cnf
	$(SED) 's|@@LIBDIR@@|$(HOST_DIR)/usr/lib|g' \
		$(HOST_DIR)/etc/ssl/openssl.cnf.d/pkcs11-aws-kms.cnf
endef

# The target copy must reference runtime paths, never $(TARGET_DIR).
define AWS_KMS_PKCS11_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/usr/lib/pkcs11 $(@D)/aws_kms_pkcs11.so
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/ssl/openssl.cnf.d \
		$(AWS_KMS_PKCS11_PKGDIR)/pkcs11-aws-kms.cnf
	$(SED) 's|@@LIBDIR@@|/usr/lib|g' \
		$(TARGET_DIR)/etc/ssl/openssl.cnf.d/pkcs11-aws-kms.cnf
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
