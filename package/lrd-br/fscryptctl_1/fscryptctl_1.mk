################################################################################
#
# fscryptctl
#
################################################################################

FSCRYPTCTL_1_VERSION = f037dcf4354ce8f25d0f371b58dfe7a7ac27576f
FSCRYPTCTL_1_SITE = $(call github,google,fscryptctl,$(FSCRYPTCTL_1_VERSION))
FSCRYPTCTL_1_LICENSE = Apache-2.0
FSCRYPTCTL_1_LICENSE_FILES = LICENSE

define FSCRYPTCTL_1_BUILD_CMDS
	$(MAKE) -C $(@D) $(TARGET_CONFIGURE_OPTS) fscryptctl
endef

define FSCRYPTCTL_1_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0755 -D $(@D)/fscryptctl $(TARGET_DIR)/usr/bin/fscryptctl
endef

define HOST_FSCRYPTCTL_1_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) -C $(@D)
endef

define HOST_FSCRYPTCTL_1_INSTALL_CMDS
        $(INSTALL) -D -m 755 $(@D)/fscryptctl $(HOST_DIR)/bin/fscryptctl
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
