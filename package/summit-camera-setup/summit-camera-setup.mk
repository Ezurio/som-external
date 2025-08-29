##########################################################################
# Camera setup for DVK boards
##########################################################################

SUMMIT_CAMERA_SETUP_VERSION = local
SUMMIT_CAMERA_SETUP_SITE = $(SUMMIT_CAMERA_SETUP_PKGDIR)/files
SUMMIT_CAMERA_SETUP_SITE_METHOD = local
SUMMIT_CAMERA_SETUP_LICENSE = Ezurio
SUMMIT_CAMERA_SETUP_LICENSE_FILES = LICENSE.ezurio

define SUMMIT_CAMERA_SETUP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0775 -t ${TARGET_DIR}/usr/bin \
		${@D}/camera-setup.sh ${@D}/camera-display.sh
endef

define SUMMIT_CAMERA_SETUP_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 -t ${TARGET_DIR}/usr/lib/systemd/system \
		${@D}/camera-handler@.service
	$(INSTALL) -D -m 0644 -t ${TARGET_DIR}/etc/udev/rules.d \
		${@D}/99-camera-devices.rules
endef

define SUMMIT_CAMERA_SETUP_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0644 ${@D}/99-camera-devices-sysv.rules \
		${TARGET_DIR}/etc/udev/rules.d/99-camera-devices.rules
endef

$(eval $(generic-package))
