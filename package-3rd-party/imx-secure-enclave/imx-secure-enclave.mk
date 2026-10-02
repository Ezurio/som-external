################################################################################
#
# imx-secure-enclave
#
################################################################################

IMX_SECURE_ENCLAVE_VERSION = lf-6.18.20-2.0.0
IMX_SECURE_ENCLAVE_SITE = $(call github,nxp-imx,imx-secure-enclave,$(IMX_SECURE_ENCLAVE_VERSION))
IMX_SECURE_ENCLAVE_LICENSE = BSD-3-Clause
IMX_SECURE_ENCLAVE_LICENSE_FILES = LICENSE
IMX_SECURE_ENCLAVE_INSTALL_STAGING = YES

# The upstream Makefile assigns its own CFLAGS (-fPIC, -Werror and the ELE
# platform defines such as -DPSA_COMPLIANT), so only the compiler is passed.
# Its targets chain order-only prerequisites that generate and then delete a
# version header, which is only safe with a serial make.
IMX_SECURE_ENCLAVE_MAKE_OPTS = \
	CC="$(TARGET_CC)" \
	PLAT=ele \
	BINDIR=/usr/bin \
	libdir=/usr/lib \
	INCLUDEDIR=/usr/include \
	ETC_DIR=/etc \
	SYSTEMD_DIR=/usr/lib/systemd/system

define IMX_SECURE_ENCLAVE_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) $(IMX_SECURE_ENCLAVE_MAKE_OPTS) \
		libs tools
endef

define IMX_SECURE_ENCLAVE_INSTALL_STAGING_CMDS
	mkdir -p $(STAGING_DIR)/etc
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) $(IMX_SECURE_ENCLAVE_MAKE_OPTS) \
		DESTDIR=$(STAGING_DIR) install
endef

define IMX_SECURE_ENCLAVE_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/etc
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D) $(IMX_SECURE_ENCLAVE_MAKE_OPTS) \
		DESTDIR=$(TARGET_DIR) install
endef

# Keep the ELE NVM key store on the persistent /perm partition instead of the
# upstream default, so persistent keys (e.g. OEM_IMPORT_MK_SK) survive reboots.
define IMX_SECURE_ENCLAVE_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(IMX_SECURE_ENCLAVE_PKGDIR)/10-summit-persistent-storage.conf \
		$(TARGET_DIR)/usr/lib/systemd/system/nvm_daemon.service.d/10-summit-persistent-storage.conf
endef

$(eval $(generic-package))
