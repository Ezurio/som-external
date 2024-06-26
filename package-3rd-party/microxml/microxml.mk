################################################################################
#
# microxml
#
################################################################################
MICROXML_VERSION = 80a15162f3a8318c70e8688d8ecbfc38676bd9a2
MICROXML_SITE = $(call github,pivasoftware,microxml,$(MICROXML_VERSION))
MICROXML_INSTALL_STAGING = YES
MICROXML_AUTORECONF = YES
MICROXML_LICENSE = LGPL-2.0+
MICROXML_LICENSE_FILES = COPYING

MICROXML_CONF_OPTS = --enable-static --prefix=$(STAGING_DIR)

define MICROXML_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/lib $(@D)/libmicroxml.so* $(@D)/libmicroxml.a
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/include $(@D)/microxml.h
	$(INSTALL) -D -m 644 -t $(STAGING_DIR)/usr/lib/pkgconfig $(@D)/microxml.pc 
endef

define MICROXML_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/usr/lib $(@D)/libmicroxml.so.*
endef

$(eval $(autotools-package))
