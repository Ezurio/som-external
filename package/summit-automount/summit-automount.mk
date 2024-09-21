#############################################################
#
# Summit Auto Mount Helper
#
#############################################################

ifeq ($(BR2_PACKAGE_SUMMIT_AUTOMOUNT_USB),y)
SUMMIT_AUTOMOUNT_INSTALL_RULES += 90-usbmount.rules
endif

ifeq ($(BR2_PACKAGE_SUMMIT_AUTOMOUNT_MMC),y)
SUMMIT_AUTOMOUNT_INSTALL_RULES += 91-mmcmount.rules
endif

SUMMIT_AUTOMOUNT_INSTALL_MOUNT_USER_EXEC = $(call qstrip,$(BR2_PACKAGE_SUMMIT_AUTOMOUNT_EXTRA))

define SUMMIT_AUTOMOUNT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin \
		$(SUMMIT_AUTOMOUNT_PKGDIR)/usb-mount.sh
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/udev/rules.d \
		$(addprefix $(SUMMIT_AUTOMOUNT_PKGDIR)/,$(SUMMIT_AUTOMOUNT_INSTALL_RULES))

	$(INSTALL) -d $(TARGET_DIR)/etc/default
	echo "MOUNT_USER_MMC=$(BR2_PACKAGE_SUMMIT_AUTOMOUNT_MMC_USER)" \
		> $(TARGET_DIR)/etc/default/usb-mount
	echo "MOUNT_USER_USB=$(BR2_PACKAGE_SUMMIT_AUTOMOUNT_USB_USER)" \
		>> $(TARGET_DIR)/etc/default/usb-mount
	echo "MOUNT_USER_EXEC='$(SUMMIT_AUTOMOUNT_INSTALL_MOUNT_USER_EXEC)'" \
		>> $(TARGET_DIR)/etc/default/usb-mount
endef

define SUMMIT_AUTOMOUNT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 -t \
		${TARGET_DIR}/usr/lib/systemd/system/systemd-udevd.service.d \
		$(SUMMIT_AUTOMOUNT_PKGDIR)/01-private-mount.conf
endef

$(eval $(generic-package))
