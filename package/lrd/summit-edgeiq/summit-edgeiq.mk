#####################################################################
# Summit EdgeIQ Support
#####################################################################

define SUMMIT_EDGEIQ_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/sbin \
		$(SUMMIT_EDGEIQ_PKGDIR)adduser \
		$(SUMMIT_EDGEIQ_PKGDIR)addgroup \
		$(SUMMIT_EDGEIQ_PKGDIR)factory_reset_edge.sh
endef

define SUMMIT_EDGEIQ_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)$(subst $\",,$(BR2_PACKAGE_SUMMIT_EDGEIQ_INSTALLDIR))/edge/init/systemd \
		 $(SUMMIT_EDGEIQ_PKGDIR)edge.service

	$(SED) 's/\/TAG_INSTALL_DIR/\$(subst $\",,$(BR2_PACKAGE_SUMMIT_EDGEIQ_INSTALLDIR))/g' \
		$(TARGET_DIR)$(subst $\",,$(BR2_PACKAGE_SUMMIT_EDGEIQ_INSTALLDIR))/edge/init/systemd/edge.service

	$(INSTALL) -d $(TARGET_DIR)/etc/systemd/system

	ln -rsf $(TARGET_DIR)$(subst $\",,$(BR2_PACKAGE_SUMMIT_EDGEIQ_INSTALLDIR))/edge/init/systemd/edge.service \
		$(TARGET_DIR)/etc/systemd/system/edge.service

	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/systemd/system/tmp.mount.d \
		 $(SUMMIT_EDGEIQ_PKGDIR)options.conf
endef

$(eval $(generic-package))
