###############################################################################
#
# Summit SSL 3.2.0 FIPS provider
#
################################################################################

SUMMITSSL_FIPS_PROVIDER_CVE_VERSION = 3.2.0

SUMMITSSL_FIPS_PROVIDER_CPE_ID_VENDOR = openssl
SUMMITSSL_FIPS_PROVIDER_CPE_ID_PRODUCT = openssl

SUMMITSSL_FIPS_PROVIDER_PREFIX = summitssl_fips

SUMMITSSL_FIPS_PROVIDER_VERSION = $(call qstrip,$(BR2_PACKAGE_SUMMITSSL_FIPS_PROVIDER_VERSION_VALUE))

SUMMITSSL_FIPS_PROVIDER_SOURCE =
SUMMITSSL_FIPS_PROVIDER_LICENSE = Apache-2.0
SUMMITSSL_FIPS_PROVIDER_EXTRA_DOWNLOADS = $(SUMMITSSL_FIPS_PROVIDER_PREFIX)$(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_ARCH))-$(SUMMITSSL_FIPS_PROVIDER_VERSION).tar.bz2

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
  SUMMITSSL_FIPS_PROVIDER_SITE = https://files.devops.rfpros.com/builds/linux/laird_openssl_fips/$(SUMMITSSL_FIPS_PROVIDER_VERSION)
else
  SUMMITSSL_FIPS_PROVIDER_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(SUMMITSSL_FIPS_PROVIDER_VERSION)
endif

define SUMMITSSL_FIPS_PROVIDER_INSTALL_TARGET_CMDS
	tar -xjvf $($(PKG)_DL_DIR)/$(SUMMITSSL_FIPS_PROVIDER_EXTRA_DOWNLOADS) -C $(TARGET_DIR) --keep-directory-symlink --no-overwrite-dir --touch
endef

$(eval $(generic-package))
