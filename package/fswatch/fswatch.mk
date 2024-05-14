#############################################################
#
# Summit Filesystem Monitor
#
#############################################################

FSWATCH_VERSION = 1.0
FSWATCH_SITE = $(call github,LairdCP,fs_watch,v$(FSWATCH_VERSION))
FSWATCH_DEPENDENCIES = inotify-tools
FSWATCH_LICENSE = GPL
FSWATCH_LICENSE_FILES = COPYING

define FSWATCH_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define FSWATCH_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/usr/bin $(@D)/fs_watch
endef

define FSWATCH_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/etc/init.d $(FSWATCH_PKGDIR)/S03fs_watch
endef

define FSWATCH_UNINSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/bin/fs_watch
endef

$(eval $(generic-package))
