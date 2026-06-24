################################################################################
#
# cst (NXP Code Signing Tool)
#
################################################################################

CST_VERSION = 4.0.1
CST_SOURCE = IMX_CST_TOOL_NEW.tgz

CST_URI ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/tools/nxp/cst/$(CST_VERSION)
CST_SITE = $(CST_URI)

CST_LICENSE = BSD-3-Clause, Apache-2.0, MIT, LGPL-2.1
CST_LICENSE_FILES = COPYING

CST_STRIP_COMPONENTS = 0

define HOST_CST_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/cst-$(CST_VERSION)/linux64/bin/cst \
		$(HOST_DIR)/bin/cst
	$(INSTALL) -D -m 0755 $(@D)/cst-$(CST_VERSION)/linux64/bin/srktool \
		$(HOST_DIR)/bin/srktool
endef

$(eval $(host-generic-package))
