##########################################################################
# Disable Console Login
##########################################################################

define LRD_DISABLE_CONSOLE_LOGIN_INSTALL_INIT_SYSTEMD
	$(INSTALL) -d $(TARGET_DIR)/etc/systemd/system-generators
	ln -fs /dev/null $(TARGET_DIR)/etc/systemd/system-generators/systemd-getty-generator
endef

ifneq ($(BR2_INIT_SYSV)$(BR2_INIT_BUSYBOX),)
define LRD_DISABLE_CONSOLE_LOGIN_SYSV
	$(SED) '/getty/d' "${TARGET_DIR}/etc/inittab"
endef

LRD_DISABLE_CONSOLE_LOGIN_TARGET_FINALIZE_HOOKS += LRD_DISABLE_CONSOLE_LOGIN_SYSV
endif

$(eval $(generic-package))

