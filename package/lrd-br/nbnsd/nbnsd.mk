#############################################################
#
# NetBIOS responder program
#
#############################################################

# source included in buildroot
NBNSD_VERSION = local
NBNSD_SOURCE =
NBNSD_LICENSE = MIT

define NBNSD_EXTRACT_CMDS
	cp package/nbnsd/nbnsd.c $(@D)
endef

define NBNSD_BUILD_CMDS
	$(TARGET_CC) $(TARGET_CFLAGS) $(TARGET_LDFLAGS) \
		$(@D)/nbnsd.c -o $(@D)/nbnsd
endef

define NBNSD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/nbnsd $(TARGET_DIR)/usr/sbin/
	$(INSTALL) -m 0755 -D package/nbnsd/S91nbnsd $(TARGET_DIR)/etc/init.d/S91nbnsd
endef

define NBNSD_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/sbin/nbnsd
	rm -f $(TARGET_DIR)/etc/init.d/S91nbnsd
endef

$(eval $(generic-package))
