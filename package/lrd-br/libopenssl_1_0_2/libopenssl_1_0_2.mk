################################################################################
#
# libopenssl-1.0.2
#
################################################################################

LIBOPENSSL_1_0_2_CVE_PRODUCT = libopenssl
LIBOPENSSL_1_0_2_CVE_VERSION = 1.0.2u

LIBOPENSSL_1_0_2_PROVIDES = openssl
LIBOPENSSL_1_0_2_CPE_ID_VENDOR = $(LIBOPENSSL_1_0_2_PROVIDES)
LIBOPENSSL_1_0_2_CPE_ID_PRODUCT = $(LIBOPENSSL_1_0_2_PROVIDES)

#0004-Fix-for-OpenSSL-1.0.2-CVE-2020-1968-from-Debian.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2020-1968

# 0005-Add-a-test-for-GENERAL_NAME_cmp.patch
# 0006-Check-that-multi-strings-CHOICE-types-don-t-use-implicit-.patch
# 0007-Complain-if-we-are-attempting-to-encode-with-an-invalid-A.patch
# 0008-Correctly-compare-EdiPartyName-in-GENERAL_NAME_cmp.patch
# 0009-DirectoryString-is-a-CHOICE-type-and-therefore-uses-expli.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2020-1971

# 0010-CVE-2021-23840.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2021-23840

# 0011-CVE-2021-23841.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2021-23841

# 0012-Fix-the-RSA_SSLV23_PADDING-padding-type.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2021-23839

# 0013-Fix-a-read-buffer-overrun-in-X509_CERT_AUX_print.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2021-3712

# 0014-Fix-possible-infinite-loop-in-BN_mod_sqrt.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2022-0778

# 0015-c_rehash-Do-not-use-shell-to-invoke-openssl.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2022-1292

# 0016-Fix-file-operations-in-c_rehash.patch
LIBOPENSSL_1_0_2_IGNORE_CVES += CVE-2022-2068

ifeq ($(BR2_PACKAGE_LAIRD_OPENSSL_FIPS),y)
# building from closed source git repository
LIBOPENSSL_1_0_2_VERSION = local
LIBOPENSSL_1_0_2_SITE = $(BR2_EXTERNAL_LRD_CLOSED_SOURCE_PATH)/package/externals/lairdssl_1_0_2
LIBOPENSSL_1_0_2_SITE_METHOD = local
else
LIBOPENSSL_1_0_2_VERSION = 1.0.2u
LIBOPENSSL_1_0_2_SITE = http://www.openssl.org/source
LIBOPENSSL_1_0_2_SOURCE = openssl-$(LIBOPENSSL_1_0_2_VERSION).tar.gz
endif

LIBOPENSSL_1_0_2_LICENSE = OpenSSL or SSLeay
LIBOPENSSL_1_0_2_LICENSE_FILES = LICENSE
LIBOPENSSL_1_0_2_INSTALL_STAGING = YES
LIBOPENSSL_1_0_2_DEPENDENCIES = zlib
HOST_LIBOPENSSL_1_0_2_DEPENDENCIES = host-zlib
LIBOPENSSL_1_0_2_TARGET_ARCH = $(call qstrip,$(BR2_PACKAGE_LIBOPENSSL_1_0_2_TARGET_ARCH))
LIBOPENSSL_1_0_2_CFLAGS = $(TARGET_CFLAGS)

# require openssl-fips built firstly
ifneq ($(BR2_PACKAGE_OPENSSL_FIPS),)
LIBOPENSSL_1_0_2_DEPENDENCIES += openssl-fips
LIBOPENSSL_1_0_2_FIPS_CFG = fips
LIBOPENSSL_1_0_2_FIPS_OPT = FIPSDIR=$(STAGING_DIR)/usr/local/ssl/fips-2.0 \
                   FIPS_SIG=$(STAGING_DIR)/usr/local/ssl/fips-2.0/bin/incore
LIBOPENSSL_1_0_2_FIPS_MAKE_OPT = FIPS_SIG=$(STAGING_DIR)/usr/local/ssl/fips-2.0/bin/incore
endif

LIBOPENSSL_1_0_2_PATCH = \
	https://gitweb.gentoo.org/repo/gentoo.git/plain/dev-libs/openssl/files/openssl-1.0.2d-parallel-build.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d \
	https://gitweb.gentoo.org/repo/gentoo.git/plain/dev-libs/openssl/files/openssl-1.0.2a-parallel-obj-headers.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d \
	https://gitweb.gentoo.org/repo/gentoo.git/plain/dev-libs/openssl/files/openssl-1.0.2a-parallel-install-dirs.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d \
	https://gitweb.gentoo.org/repo/gentoo.git/plain/dev-libs/openssl/files/openssl-1.0.2a-parallel-symlinking.patch?id=c8abcbe8de5d3b6cdd68c162f398c011ff6e2d9d

ifeq ($(BR2_m68k_cf),y)
# relocation truncated to fit: R_68K_GOT16O
LIBOPENSSL_1_0_2_CFLAGS += -mxgot
# resolves an assembler "out of range error" with blake2 and sha512 algorithms
LIBOPENSSL_CFLAGS += -DOPENSSL_SMALL_FOOTPRINT
endif

ifeq ($(BR2_USE_MMU),)
LIBOPENSSL_1_0_2_CFLAGS += -DHAVE_FORK=0
endif

ifeq ($(BR2_PACKAGE_HAS_CRYPTODEV),y)
LIBOPENSSL_1_0_2_CFLAGS += -DHAVE_CRYPTODEV -DUSE_CRYPTODEV_DIGESTS
LIBOPENSSL_1_0_2_DEPENDENCIES += cryptodev
endif

define HOST_LIBOPENSSL_1_0_2_CONFIGURE_CMDS
	(cd $(@D); \
		$(HOST_CONFIGURE_OPTS) \
		./config \
		--prefix=$(HOST_DIR) \
		--openssldir=$(HOST_DIR)/etc/ssl \
		--libdir=/lib \
		shared \
		zlib-dynamic \
	)
	$(SED) "s#-O[0-9]#$(HOST_CFLAGS)#" $(@D)/Makefile
endef

ifeq ($(BR2_PACKAGE_LAIRD_OPENSSL_FIPS_DEBUG),y)
LIBOPENSSL_1_0_2_DEBUG = debug-
endif

define LIBOPENSSL_1_0_2_CONFIGURE_CMDS
	(cd $(@D); \
		$(TARGET_CONFIGURE_ARGS) \
		$(TARGET_CONFIGURE_OPTS) \
		$(LIBOPENSSL_1_0_2_FIPS_OPT) \
		./Configure \
			$(LIBOPENSSL_1_0_2_DEBUG)$(LIBOPENSSL_TARGET_ARCH) \
			--prefix=/usr \
			--openssldir=/etc/ssl \
			--libdir=/lib \
			$(if $(BR2_TOOLCHAIN_HAS_THREADS),threads,no-threads) \
			$(if $(BR2_STATIC_LIBS),no-shared,shared) \
			enable-camellia \
			enable-tlsext \
			no-rc5 \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_RC2),,no-rc2) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_RC4),,no-rc4) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_MD2),,no-md2) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_MD4),,no-md4) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_MDC2),,no-mdc2) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_IDEA),,no-idea) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_SEED),,no-seed) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_DES),,no-des) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_RMD160),,no-rmd160) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_WHIRLPOOL),,no-whirlpool) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_BLOWFISH),,no-bf) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_SSL),,no-ssl) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_SSL2),,no-ssl2) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_SSL3),,no-ssl3) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_WEAK_SSL),,no-weak-ssl-ciphers) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_PSK),,no-psk) \
			$(if $(BR2_PACKAGE_LIBOPENSSL_ENABLE_COMP),,no-comp) \
			$(if $(BR2_STATIC_LIBS),zlib,zlib-dynamic) \
			$(if $(BR2_STATIC_LIBS),no-dso) \
			$(LIBOPENSSL_1_0_2_FIPS_CFG) \
	)
	$(SED) "s#-march=[-a-z0-9] ##" -e "s#-mcpu=[-a-z0-9] ##g" $(@D)/Makefile
	$(SED) "s#-O[0-9sg]#$(LIBOPENSSL_1_0_2_CFLAGS)#" $(@D)/Makefile
	$(SED) "s# build_tests##" $(@D)/Makefile
endef

# libdl is not available in a static build, and this is not implied by no-dso
ifeq ($(BR2_STATIC_LIBS),y)
define LIBOPENSSL_1_0_2_FIXUP_STATIC_MAKEFILE
	$(SED) 's#-ldl##g' $(@D)/Makefile
endef
LIBOPENSSL_1_0_2_POST_CONFIGURE_HOOKS += LIBOPENSSL_1_0_2_FIXUP_STATIC_MAKEFILE
endif

define HOST_LIBOPENSSL_1_0_2_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D)
endef

define LIBOPENSSL_1_0_2_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(LIBOPENSSL_1_0_2_FIPS_MAKE_OPT) -C $(@D)
endef

define LIBOPENSSL_1_0_2_INSTALL_STAGING_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) INSTALL_PREFIX=$(STAGING_DIR) install
endef

define HOST_LIBOPENSSL_1_0_2_INSTALL_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D) install
endef

define LIBOPENSSL_1_0_2_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) INSTALL_PREFIX=$(TARGET_DIR) install
	rm -rf $(TARGET_DIR)/usr/lib/ssl
	rm -f $(TARGET_DIR)/usr/bin/c_rehash
endef

# libdl has no business in a static build
ifeq ($(BR2_STATIC_LIBS),y)
define LIBOPENSSL_1_0_2_FIXUP_STATIC_PKGCONFIG
	$(SED) 's#-ldl##' $(STAGING_DIR)/usr/lib/pkgconfig/libcrypto.pc
	$(SED) 's#-ldl##' $(STAGING_DIR)/usr/lib/pkgconfig/libssl.pc
	$(SED) 's#-ldl##' $(STAGING_DIR)/usr/lib/pkgconfig/openssl.pc
endef
LIBOPENSSL_1_0_2_POST_INSTALL_STAGING_HOOKS += LIBOPENSSL_1_0_2_FIXUP_STATIC_PKGCONFIG
endif

ifneq ($(BR2_STATIC_LIBS),y)
# libraries gets installed read only, so strip fails
define LIBOPENSSL_1_0_2_INSTALL_FIXUPS_SHARED
	chmod +w $(TARGET_DIR)/usr/lib/engines/lib*.so
	for i in $(addprefix $(TARGET_DIR)/usr/lib/,libcrypto.so.* libssl.so.*); \
	do chmod +w $$i; done
endef
LIBOPENSSL_1_0_2_POST_INSTALL_TARGET_HOOKS += LIBOPENSSL_1_0_2_INSTALL_FIXUPS_SHARED
endif

ifeq ($(BR2_PACKAGE_PERL),)
define LIBOPENSSL_1_0_2_REMOVE_PERL_SCRIPTS
	$(RM) -f $(TARGET_DIR)/etc/ssl/misc/{CA.pl,tsget}
endef
LIBOPENSSL_1_0_2_POST_INSTALL_TARGET_HOOKS += LIBOPENSSL_1_0_2_REMOVE_PERL_SCRIPTS
endif

ifeq ($(BR2_PACKAGE_LIBOPENSSL_BIN),)
define LIBOPENSSL_1_0_2_REMOVE_BIN
	$(RM) -f $(TARGET_DIR)/usr/bin/openssl
	$(RM) -f $(TARGET_DIR)/etc/ssl/misc/{CA.*,c_*}
endef
LIBOPENSSL_1_0_2_POST_INSTALL_TARGET_HOOKS += LIBOPENSSL_1_0_2_REMOVE_BIN
endif

ifneq ($(BR2_PACKAGE_LIBOPENSSL_1_0_2_ENGINES),y)
define LIBOPENSSL_1_0_2_REMOVE_LIBOPENSSL_1_0_2_ENGINES
	rm -rf $(TARGET_DIR)/usr/lib/engines
endef
LIBOPENSSL_1_0_2_POST_INSTALL_TARGET_HOOKS += LIBOPENSSL_1_0_2_REMOVE_LIBOPENSSL_1_0_2_ENGINES
endif

$(eval $(generic-package))
$(eval $(host-generic-package))
