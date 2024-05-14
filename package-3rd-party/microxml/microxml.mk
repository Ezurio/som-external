################################################################################
#
# microxml
#
################################################################################
MICROXML_VERSION = 80a15162f3a8318c70e8688d8ecbfc38676bd9a2
MICROXML_SITE = https://github.com/pivasoftware/microxml.git
MICROXML_SITE_METHOD = git
MICROXML_INSTALL_STAGING = YES
MICROXML_AUTORECONF = YES
MICROXML_LICENSE = GPLv2+
MICROXML_LICENSE_FILES = COPYING

MICROXML_CONF_OPTS = --enable-static --prefix=$(STAGING_DIR)

define MICROXML_INSTALL_STAGING_CMDS
	$(INSTALL) -D -m 0755 $(@D)/libmicroxml.so* $(STAGING_DIR)/usr/lib
	$(INSTALL) -D -m 0755 $(@D)/libmicroxml.a $(STAGING_DIR)/usr/lib
	$(INSTALL) -D -m 0644 $(@D)/microxml.h $(STAGING_DIR)/usr/include
	$(INSTALL) -D -m 0655 $(@D)/microxml.pc $(STAGING_DIR)/usr/lib/pkgconfig
endef

define MICROXML_INSTALL_TARGET_CMDS
	rm -f $(TARGET_DIR)/usr/lib/libmicroxml.so*
	$(INSTALL) -D -m 755 $(@D)/libmicroxml.so* $(TARGET_DIR)/usr/lib/
endef

$(eval $(autotools-package))
