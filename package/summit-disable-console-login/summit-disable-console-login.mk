##########################################################################
# Disable Console Login
##########################################################################

ifeq ($(BR2_LRD_DEVEL_BUILD),)

ifeq ($(BR2_INIT_SYSTEMD),y)
define SUMMIT_DISABLE_CONSOLE_LOGIN
	$(INSTALL) -d $(TARGET_DIR)/etc/systemd/system-generators
	ln -fs /dev/null $(TARGET_DIR)/etc/systemd/system-generators/systemd-getty-generator
endef

SUMMIT_DISABLE_CONSOLE_LOGIN_ROOTFS_PRE_CMD_HOOKS += SUMMIT_DISABLE_CONSOLE_LOGIN
else ifneq ($(BR2_INIT_SYSV)$(BR2_INIT_BUSYBOX),)
define SUMMIT_DISABLE_CONSOLE_LOGIN
	$(SED) '/getty/d' "${TARGET_DIR}/etc/inittab"
endef

SUMMIT_DISABLE_CONSOLE_LOGIN_ROOTFS_PRE_CMD_HOOKS += SUMMIT_DISABLE_CONSOLE_LOGIN
endif

$(eval $(generic-package))
endif
