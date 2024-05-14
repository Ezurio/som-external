DEMO_GUI_VERSION = 5.9.4
DEMO_GUI_LICENSE = GPL-2.0
DEMO_GUI_SITE = $(DEMO_GUI_PKGDIR)/demo
DEMO_GUI_SITE_METHOD = local
DEMO_GUI_DEPENDENCIES = qt5base libdrm cairo libplanes cjson lua summit-network-manager

define DEMO_GUI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/opt $(@D)/misc/systime $(@D)/network/network-demo 
endef

$(eval $(qmake-package))
