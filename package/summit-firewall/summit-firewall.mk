#############################################################
#
# Summit Basic Wi-Fi NAT/Firewall
#
#############################################################

SUMMIT_FIREWALL_INT_IF = $(call qstrip,$(BR2_PACKAGE_SUMMIT_FIREWALL_INT_IF))
SUMMIT_FIREWALL_IPV4 = $(call qstrip,$(BR2_PACKAGE_SUMMIT_FIREWALL_INT_IF_IPV4))
SUMMIT_FIREWALL_EXT_IF = $(call qstrip,$(BR2_PACKAGE_SUMMIT_FIREWALL_EXT_IF))

define SUMMIT_FIREWALL_INSTALL_TARGET_CMDS
	rsync -rlpDWK --no-perms --exclude=.empty  $(SUMMIT_FIREWALL_PKGDIR)/rootfs-additions/ $(TARGET_DIR)/

	mv -f $(TARGET_DIR)/usr/lib/NetworkManager/system-connections/internal-@@INT_IF@@.nmconnection \
		$(TARGET_DIR)/usr/lib/NetworkManager/system-connections/internal-$(SUMMIT_FIREWALL_INT_IF).nmconnection
	chmod 0600 $(TARGET_DIR)/usr/lib/NetworkManager/system-connections/internal-$(SUMMIT_FIREWALL_INT_IF).nmconnection

	$(SED) 's,@@INT_IF@@,$(SUMMIT_FIREWALL_INT_IF),g;s,@@EXT_IF@@,$(SUMMIT_FIREWALL_EXT_IF),g;s,@@IPV4@@,$(SUMMIT_FIREWALL_IPV4),g' \
		$(TARGET_DIR)/etc/wifi-nat.conf $(TARGET_DIR)/etc/wifi6-nat.conf \
		$(TARGET_DIR)/etc/NetworkManager/conf.d/10-no-firewall.conf \
		$(TARGET_DIR)/usr/lib/NetworkManager/system-connections/internal-$(SUMMIT_FIREWALL_INT_IF).nmconnection
endef

define SUMMIT_FIREWALL_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 $(SUMMIT_FIREWALL_PKGDIR)/wifi-nat.service \
		$(TARGET_DIR)/usr/lib/systemd/system/wifi-nat.service
endef

$(eval $(generic-package))
