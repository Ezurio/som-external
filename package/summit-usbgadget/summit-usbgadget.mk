#############################################################
#
# Summit USB Ethernet Gadget Helper
#
#############################################################

ifeq ($(BR2_PACKAGE_SUMMIT_FIREWALL),)
ifneq ($(BR2_PACKAGE_SUMMIT_NETWORK_MANAGER)$(BR2_PACKAGE_NETWORK_MANAGER),)
define SUMMIT_USBGADGET_INSTALL_NM
	$(INSTALL) -D -m 0600 -t $(TARGET_DIR)/usr/lib/NetworkManager/system-connections/ \
		$(SUMMIT_USBGADGET_PKGDIR)/shared-usb0.nmconnection
endef
endif
endif

define SUMMIT_USBGADGET_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin/ \
		$(SUMMIT_USBGADGET_PKGDIR)/usb-gadget.sh

	$(SUMMIT_USBGADGET_INSTALL_NM)
endef

define SUMMIT_USBGADGET_INSTALL_INIT_CONFIG
	mkdir -p "$(TARGET_DIR)/etc/default"
	echo 'USB_GADGET_ETHER_PORTS=$(BR2_PACKAGE_SUMMIT_USBGADGET_ETHERNET_PORTS)'       > $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER=$(BR2_PACKAGE_SUMMIT_USBGADGET_TYPE_STRING)'               >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER_LOCAL_MAC=$(BR2_PACKAGE_SUMMIT_USBGADGET_LOCAL_MAC)'       >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER_REMOTE_MAC=$(BR2_PACKAGE_SUMMIT_USBGADGET_REMOTE_MAC)'     >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_SERIAL_PORTS=$(BR2_PACKAGE_SUMMIT_USBGADGET_SERIAL_PORTS)'       >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_VENDOR_ID=$(BR2_PACKAGE_SUMMIT_USBGADGET_VENDOR_ID)'             >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_PRODUCT_ID=$(BR2_PACKAGE_SUMMIT_USBGADGET_PRODUCT_ID)'           >> $(TARGET_DIR)/etc/default/usb-gadget
endef

ifneq ($(BR2_PACKAGE_SUMMIT_USBGADGET_OTG),y)
define SUMMIT_USBGADGET_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 $(SUMMIT_USBGADGET_PKGDIR)/usb-gadget.service \
		$(TARGET_DIR)/usr/lib/systemd/system/usb-gadget.service

	$(SUMMIT_USBGADGET_INSTALL_INIT_CONFIG)
endef

ifeq ($(BR2_PACKAGE_SUMMIT_LEGACY),y)
define SUMMIT_USBGADGET_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(SUMMIT_USBGADGET_PKGDIR)/S43usb-gadget \
		$(TARGET_DIR)/etc/init.d/opt/S91g_ether

	$(SUMMIT_USBGADGET_INSTALL_INIT_CONFIG)
endef
else
define SUMMIT_USBGADGET_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/etc/init.d/ \
		$(SUMMIT_USBGADGET_PKGDIR)/S43usb-gadget

	$(SUMMIT_USBGADGET_INSTALL_INIT_CONFIG)
endef
endif
else
define SUMMIT_USBGADGET_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 $(SUMMIT_USBGADGET_PKGDIR)/usb-gadget.service.otg \
		$(TARGET_DIR)/usr/lib/systemd/system/usb-gadget.service

	$(SUMMIT_USBGADGET_INSTALL_INIT_CONFIG)
endef

define SUMMIT_USBGADGET_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(SUMMIT_USBGADGET_PKGDIR)/usb-gadget.rules.otg \
		$(TARGET_DIR)/etc/udev/rules.d/99-usb-gadget.rules

	$(SUMMIT_USBGADGET_INSTALL_INIT_CONFIG)
endef
endif

$(eval $(generic-package))
