#############################################################
#
# Laird Auto Mount Helper
#
#############################################################

ifeq ($(BR2_PACKAGE_LRD_AUTOMOUNT_USB),y)
LRD_AUTOMOUNT_INSTALL_RULES += 90-usbmount.rules
endif

ifeq ($(BR2_PACKAGE_LRD_AUTOMOUNT_MMC),y)
LRD_AUTOMOUNT_INSTALL_RULES += 91-mmcmount.rules
endif

LRD_AUTOMOUNT_INSTALL_MOUNT_USER_EXEC = $(call qstrip,$(BR2_PACKAGE_LRD_AUTOMOUNT_EXTRA))

define LRD_AUTOMOUNT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin \
		$(LRD_AUTOMOUNT_PKGDIR)usb-mount.sh
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/udev/rules.d \
		$(addprefix $(LRD_AUTOMOUNT_PKGDIR),$(LRD_AUTOMOUNT_INSTALL_RULES))

	$(INSTALL) -d $(TARGET_DIR)/etc/default
	echo "MOUNT_USER_MMC=$(BR2_PACKAGE_LRD_AUTOMOUNT_MMC_USER)" \
		> $(TARGET_DIR)/etc/default/usb-mount
	echo "MOUNT_USER_USB=$(BR2_PACKAGE_LRD_AUTOMOUNT_USB_USER)" \
		>> $(TARGET_DIR)/etc/default/usb-mount
	echo "MOUNT_USER_EXEC='$(LRD_AUTOMOUNT_INSTALL_MOUNT_USER_EXEC)'" \
		>> $(TARGET_DIR)/etc/default/usb-mount

	${LRD_AUTOMOUNT_INSTALL_USB_UPDATE}
endef

$(eval $(generic-package))
