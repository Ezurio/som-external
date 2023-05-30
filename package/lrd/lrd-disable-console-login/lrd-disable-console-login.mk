##########################################################################
# Disable Console Login
##########################################################################

ifeq ($(BR2_LRD_IG60_DEVEL)$(BR2_LRD_DEVEL_BUILD),)

ifeq ($(BR2_INIT_SYSTEMD),y)
define LRD_DISABLE_CONSOLE_LOGIN
	$(INSTALL) -d $(TARGET_DIR)/etc/systemd/system-generators
	ln -fs /dev/null $(TARGET_DIR)/etc/systemd/system-generators/systemd-getty-generator
endef

LRD_DISABLE_CONSOLE_LOGIN_ROOTFS_PRE_CMD_HOOKS += LRD_DISABLE_CONSOLE_LOGIN
else ifneq ($(BR2_INIT_SYSV)$(BR2_INIT_BUSYBOX),)
define LRD_DISABLE_CONSOLE_LOGIN
	$(SED) '/getty/d' "${TARGET_DIR}/etc/inittab"
endef

LRD_DISABLE_CONSOLE_LOGIN_ROOTFS_PRE_CMD_HOOKS += LRD_DISABLE_CONSOLE_LOGIN
endif

$(eval $(generic-package))
endif

