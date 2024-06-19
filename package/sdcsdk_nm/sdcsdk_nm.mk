#############################################################
#
# SDC SDK NM
#
#############################################################

SDCSDK_NM_VERSION = local
SDCSDK_NM_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/sdcsdk_nm
SDCSDK_NM_SITE_METHOD = local
SDCSDK_LICENSE = Ezurio
SDCSDK_LICENSE_FILES = LICENSE.ezurio
SDCSDK_NM_INSTALL_STAGING = YES
SDCSDK_NM_DEPENDENCIES = libnl host-pkgconf summit-userspace-examples

define SDCSDK_NM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define SDCSDK_NM_INSTALL_STAGING_CMDS
	ln -rsf $(TARGET_DIR)/usr/lib/libsdc_sdk_nm.so.1 $(STAGING_DIR)/usr/lib/libsdc_sdk_nm.so
	$(INSTALL) -D -m 0644 -t $(STAGING_DIR)/usr/include \
		$(@D)/src/sdc_sdk.h \
		$(@D)/src/sdc_events.h \
		$(@D)/src/sdc_sdk_types.h \
		$(@D)/src/sdc_sdk_deprecated.h \
		$(@D)/src/sdc_sdk_helper.h \
		$(@D)/src/lrd_sdk_eni.h \
		$(@D)/src/sdc_sdk_private.h \
		$(@D)/src/sdc_sdk_version.h \
		$(@D)/src/include/libsdcsdk_sys.h \
		$(@D)/src/include/libsdcsdk_types.h
endef

define SDCSDK_NM_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libsdc_sdk_nm.so.1.0 $(TARGET_DIR)/usr/lib/libsdc_sdk_nm.so.1.0
	ln -rsf $(TARGET_DIR)/usr/lib/libsdc_sdk_nm.so.1.0 $(TARGET_DIR)/usr/lib/libsdc_sdk_nm.so.1
endef

$(eval $(generic-package))
