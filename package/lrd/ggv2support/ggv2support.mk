#####################################################################
# Laird Industrial Gateway ggv2support
#####################################################################

define GGV2SUPPORT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/bin/ \
		$(GGV2SUPPORT_PKGDIR)ggv2_prepare_sdcard.sh \
		$(GGV2SUPPORT_PKGDIR)/ggv2_mount_sdcard.sh
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/modules-load.d \
		$(GGV2SUPPORT_PKGDIR)f2fs.conf
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/sysctl.d \
		$(GGV2SUPPORT_PKGDIR)min-free-kbytes.conf
endef

define GGV2SUPPORT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/systemd/system \
		$(GGV2SUPPORT_PKGDIR)ggv2runner.service \
		$(GGV2SUPPORT_PKGDIR)media-mmcblk0p1-swapfile.swap \
		$(GGV2SUPPORT_PKGDIR)ggv2sdmount.service
endef

define GGV2SUPPORT_USERS
	ggc_user 201 ggc_group 201 * - - systemd-journal,disk
endef

$(eval $(generic-package))
