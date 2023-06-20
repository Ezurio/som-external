##########################################################################
# Sentrius IG60 TTY Utils
##########################################################################

define IG_TTY_UTILS_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -t $(TARGET_DIR)/etc/udev/rules.d -m 644 $(IG_TTY_UTILS_PKGDIR)/70-usb-tty.rules
endef

$(eval $(generic-package))

