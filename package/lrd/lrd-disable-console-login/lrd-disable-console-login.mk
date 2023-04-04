##########################################################################
# Disable Console Login
##########################################################################

define LRD_DISABLE_CONSOLE_LOGIN_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -t $(TARGET_DIR)/usr/lib/systemd/system/system-preset \
		-m 644 $(LRD_DISABLE_CONSOLE_LOGIN_PKGDIR)/01-disable-getty.preset
endef

ifneq ($(BR2_INIT_SYSV)$(BR2_INIT_BUSYBOX),)
define LRD_DISABLE_CONSOLE_LOGIN_SYSV
	$(SED) '/getty/d' "${TARGET_DIR}/etc/inittab"
endef

LRD_DISABLE_CONSOLE_LOGIN_TARGET_FINALIZE_HOOKS += LRD_DISABLE_CONSOLE_LOGIN_SYSV
endif

$(eval $(generic-package))

