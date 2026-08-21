###############################################################################
#
# Summit OpenSSL 3.2.0 FIPS provider
#
################################################################################

SUMMIT_OPENSSL_FIPS_PROVIDER_CPE_ID_VENDOR = openssl
SUMMIT_OPENSSL_FIPS_PROVIDER_CPE_ID_PRODUCT = openssl
SUMMIT_OPENSSL_FIPS_PROVIDER_CPE_ID_VERSION = 3.2.0

SUMMIT_OPENSSL_FIPS_PROVIDER_VERSION = $(call qstrip,$(BR2_PACKAGE_SUMMIT_OPENSSL_FIPS_PROVIDER_VERSION_VALUE))
SUMMIT_OPENSSL_FIPS_PROVIDER_SOURCE = summit_openssl_fips_provider-$(call qstrip,$(BR2_PACKAGE_SUMMIT_OPENSSL_FIPS_PROVIDER_ARCH))-$(SUMMIT_OPENSSL_FIPS_PROVIDER_VERSION).tar.bz2
SUMMIT_OPENSSL_FIPS_PROVIDER_LICENSE = Ezurio & Apache-2.0
SUMMIT_OPENSSL_FIPS_PROVIDER_LICENSE_FILES = LICENSE.ezurio LICENSE.openssl

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
  SUMMIT_OPENSSL_FIPS_PROVIDER_SITE = $(SUMMIT_SOM_URI_BASE_INTERNAL)/laird_openssl_fips/$(SUMMIT_OPENSSL_FIPS_PROVIDER_VERSION)
else
  SUMMIT_OPENSSL_FIPS_PROVIDER_SITE = https://github.com/Ezurio/summit_openssl_fips_provider/releases/download/LRD-REL-$(SUMMIT_OPENSSL_FIPS_PROVIDER_VERSION)
endif

SUMMIT_OPENSSL_FIPS_PROVIDER_DEPENDENCIES = libopenssl_3_0

define SUMMIT_OPENSSL_FIPS_PROVIDER_INSTALL_TARGET_CMDS
  rsync -rlpDWK --no-perms  $(@D)/usr $(TARGET_DIR)
  $(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/ssl/openssl.cnf.d \
	  $(SUMMIT_OPENSSL_FIPS_PROVIDER_PKGDIR)/fips.cnf
endef

$(eval $(generic-package))
