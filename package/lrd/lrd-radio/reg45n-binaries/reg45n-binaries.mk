REG45N_BINARIES_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
REG45N_BINARIES_SOURCE = reg45n$(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_ARCH))-$(REG45N_BINARIES_VERSION).tar.bz2
REG45N_BINARIES_STRIP_COMPONENTS = 0
REG45N_BINARIES_LICENSE = GPL-2.0

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
	REG45N_BINARIES_SITE = https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux/reg45n/laird/$(REG45N_BINARIES_VERSION)
else
	REG45N_BINARIES_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(REG45N_BINARIES_VERSION)
endif

define REG45N_BINARIES_BUILD_CMDS
	(cd $(@D) && ./$(REG45N_BINARIES_SOURCE:%.tar.bz2=%.sh) tar)
	mkdir -p $(@D)/files
	tar -xvjf $(@D)/$(REG45N_BINARIES_SOURCE) -C $(@D)/files/
endef

define REG45N_BINARIES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/files/lru $(TARGET_DIR)/usr/bin/lru
	$(INSTALL) -D -m 755 $(@D)/files/smu_cli $(TARGET_DIR)/usr/bin/smu_cli
	$(INSTALL) -D -m 644 $(@D)/files/utf*.bin -t $(TARGET_DIR)/lib/firmware/ath6k/AR6003/hw2.1.1/
	$(INSTALL) -D -m 755 $(@D)/files/tcmd.sh $(TARGET_DIR)/usr/bin/tcmd.sh
endef

$(eval $(generic-package))
