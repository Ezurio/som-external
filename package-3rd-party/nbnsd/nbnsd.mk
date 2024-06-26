#############################################################
#
# NetBIOS responder program
#
#############################################################
NBNSD_VERSION = local
NBNSD_SITE = $(NBNSD_PKGDIR)
NBNSD_SITE_METHOD = local
NBNSD_LICENSE = MIT
NBNSD_LICENSE_FILES = nbnsd.c

define NBNSD_EXTRACT_CMDS
	cp $(NBNSD_PKGDIR)/nbnsd.c $(@D)
endef

define NBNSD_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		$(@D)/nbnsd.c -o $(@D)/nbnsd
endef

define NBNSD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/sbin $(@D)/nbnsd
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/etc/init.d $(NBNSD_PKGDIR)/S91nbnsd
endef

$(eval $(generic-package))
