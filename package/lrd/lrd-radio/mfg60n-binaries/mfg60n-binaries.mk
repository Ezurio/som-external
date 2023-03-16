MFG60N_BINARIES_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
MFG60N_BINARIES_SOURCE = mfg60n$(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_ARCH))-$(MFG60N_BINARIES_VERSION).tar.bz2
MFG60N_BINARIES_STRIP_COMPONENTS = 0
MFG60N_BINARIES_LICENSE = GPL-2.0

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
	MFG60N_BINARIES_SITE = https://files.devops.rfpros.com/builds/linux/mfg60n/laird/$(MFG60N_BINARIES_VERSION)
	ifeq ($(shell wget -q --spider $(MFG60N_BINARIES_SITE) && echo ok),)
		MFG60N_BINARIES_SITE = https://files.devops.rfpros.com/builds/linux/mfg60n-arm-eabihf/laird/$(MFG60N_BINARIES_VERSION)
	endif
else
	MFG60N_BINARIES_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(MFG60N_BINARIES_VERSION)
endif

define MFG60N_BINARIES_BUILD_CMDS
	(cd $(@D) && ./$(MFG60N_BINARIES_SOURCE:%.tar.bz2=%.sh) tar)
	mkdir -p $(@D)/files
	tar -xvjf $(@D)/$(MFG60N_BINARIES_SOURCE) -C $(@D)/files/
endef

ifeq ($(BR2_PACKAGE_MFG60N_BINARIES_LMU),y)
define MFG60N_BINARIES_LMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/files/lmu $(TARGET_DIR)/usr/bin/lmu
endef
endif

ifeq ($(BR2_PACKAGE_MFG60N_BINARIES_REGULATORY),y)

ifneq ($(BR2_PACKAGE_BLUEZ5_UTILS)$(BR2_PACKAGE_BLUEZ4_UTILS),)
define MFG60N_BINARIES_BTLRU_INSTALL_TARGET_CMD
	$(INSTALL) -D -m 755 $(@D)/files/btlru $(TARGET_DIR)/usr/bin/btlru
endef
endif

define MFG60N_BINARIES_REGULATORY_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/files/lru $(TARGET_DIR)/usr/bin/lru
	$(MFG60N_BINARIES_BTLRU_INSTALL_TARGET_CMD)
	$(INSTALL) -D -m 644 $(@D)/files/88W8997_mfg* -t $(TARGET_DIR)/lib/firmware/lrdmwl/
endef
endif

define MFG60N_BINARIES_INSTALL_TARGET_CMDS
	$(MFG60N_BINARIES_LMU_INSTALL_TARGET_CMDS)
	$(MFG60N_BINARIES_REGULATORY_INSTALL_TARGET_CMDS)
endef

$(eval $(generic-package))
