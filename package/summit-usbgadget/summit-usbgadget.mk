#############################################################
#
# Summit USB Ethernet Gadget Helper
#
#############################################################

SUMMIT_USBGADGET_VERSION = local
SUMMIT_USBGADGET_SITE = $(SUMMIT_USBGADGET_PKGDIR)/files
SUMMIT_USBGADGET_SITE_METHOD = local
SUMMIT_USBGADGET_LICENSE = Ezurio
SUMMIT_USBGADGET_LICENSE_FILES = LICENSE.ezurio

SUMMIT_USBGADGET_SYSV_SCRIPT = \
	$(if $(BR2_PACKAGE_SUMMIT_LEGACY),opt/S91g_ether,S43usb-gadget)

ifeq ($(BR2_PACKAGE_SUMMIT_FIREWALL),)
ifneq ($(BR2_PACKAGE_SUMMIT_NETWORK_MANAGER)$(BR2_PACKAGE_NETWORK_MANAGER),)
define SUMMIT_USBGADGET_INSTALL_NM
	$(INSTALL) -D -m 0600 -t $(TARGET_DIR)/usr/lib/NetworkManager/system-connections/ \
		$(@D)/shared-usb*.nmconnection
endef
endif
endif

define SUMMIT_USBGADGET_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin $(@D)/usb-gadget.sh

	mkdir -p "$(TARGET_DIR)/etc/default"
	echo 'USB_GADGET_ETHER_PORTS=$(BR2_PACKAGE_SUMMIT_USBGADGET_ETHERNET_PORTS)'       > $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER=$(BR2_PACKAGE_SUMMIT_USBGADGET_TYPE_STRING)'               >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER_LOCAL_MAC=$(BR2_PACKAGE_SUMMIT_USBGADGET_LOCAL_MAC)'       >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_ETHER_REMOTE_MAC=$(BR2_PACKAGE_SUMMIT_USBGADGET_REMOTE_MAC)'     >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_SERIAL_SOURCE=$(BR2_PACKAGE_SUMMIT_USBGADGET_SERIAL_SOURCE_STRING)' >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_SERIAL_NUMBER=$(BR2_PACKAGE_SUMMIT_USBGADGET_SERIAL_NUMBER)'     >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_SERIAL_PORTS=$(BR2_PACKAGE_SUMMIT_USBGADGET_SERIAL_PORTS)'       >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_VENDOR_ID=$(BR2_PACKAGE_SUMMIT_USBGADGET_VENDOR_ID)'             >> $(TARGET_DIR)/etc/default/usb-gadget
	echo 'USB_GADGET_PRODUCT_ID=$(BR2_PACKAGE_SUMMIT_USBGADGET_PRODUCT_ID)'           >> $(TARGET_DIR)/etc/default/usb-gadget

	$(SUMMIT_USBGADGET_INSTALL_NM)
endef

ifeq ($(BR2_PACKAGE_SUMMIT_USBGADGET_OTG),y)

# OTG configuration
define SUMMIT_USBGADGET_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/usb-gadget.rules.otg.systemd \
		$(TARGET_DIR)/etc/udev/rules.d/99-usb-gadget.rules
	$(INSTALL) -D -m 0644 $(@D)/usb-gadget@.service.otg \
		$(TARGET_DIR)/usr/lib/systemd/system/usb-gadget@.service
endef

define SUMMIT_USBGADGET_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0644 $(@D)/usb-gadget.rules.otg \
		$(TARGET_DIR)/etc/udev/rules.d/99-usb-gadget.rules
endef
# OTG configuration done

else

# Non-OTG configuration
define SUMMIT_USBGADGET_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/usb-gadget.service \
		$(TARGET_DIR)/usr/lib/systemd/system/usb-gadget.service
endef

define SUMMIT_USBGADGET_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(@D)/S43usb-gadget \
		$(TARGET_DIR)/etc/init.d/$(SUMMIT_USBGADGET_SYSV_SCRIPT)
endef
# Non-OTG configuration done

endif

$(eval $(generic-package))
