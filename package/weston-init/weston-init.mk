################################################################################
#
# weston-init
#
################################################################################

WESTON_INIT_LICENSE = MIT
WESTON_INIT_LICENSE_FILES =

ifeq ($(BR2_PACKAGE_WESTON_INIT_AUTOLOGIN),y)
WESTON_INIT_DEPENDENCIES += linux-pam
define WESTON_INIT_PAM_INSTALL
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/pam.d \
		$(WESTON_INIT_PKGDIR)/weston-autologin
endef
endif

define WESTON_INIT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/profile.d \
		$(WESTON_INIT_PKGDIR)/weston-socket.sh

	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc/xdg/weston \
		$(WESTON_INIT_PKGDIR)/weston.ini

	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/etc \
		$(WESTON_INIT_PKGDIR)/Ezurio_logo-White_Red.png

	$(WESTON_INIT_PAM_INSTALL)
endef

define WESTON_INIT_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/usr/bin \
		$(WESTON_INIT_PKGDIR)/weston-start

	$(INSTALL) -D -m 0755 -t $(TARGET_DIR)/etc/init.d \
		$(WESTON_INIT_PKGDIR)/S12weston
endef

define WESTON_INIT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 -t $(TARGET_DIR)/usr/lib/systemd/system \
		$(WESTON_INIT_PKGDIR)/weston.service \
		$(WESTON_INIT_PKGDIR)/weston.socket
endef

define WESTON_INIT_USERS
	- - wayland -1 * - - - -
	- - seat -1 * - - - -
	weston -2 weston -2 ! /home/weston /bin/sh video,input,render,seat,wayland Weston Wayland compositor
endef

$(eval $(generic-package))
