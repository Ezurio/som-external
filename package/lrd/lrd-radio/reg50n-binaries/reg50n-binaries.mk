REG50N_BINARIES_VERSION = $(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_VERSION_VALUE))
REG50N_BINARIES_SOURCE = reg50n$(call qstrip,$(BR2_PACKAGE_LRD_RADIO_STACK_ARCH))-$(REG50N_BINARIES_VERSION).tar.bz2
REG50N_BINARIES_STRIP_COMPONENTS = 0
REG50N_BINARIES_LICENSE = GPL-2.0

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
	REG50N_BINARIES_SITE = https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux/reg50n/laird/$(REG50N_BINARIES_VERSION)
else
	REG50N_BINARIES_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(REG50N_BINARIES_VERSION)
endif

define REG50N_BINARIES_BUILD_CMDS
	(cd $(@D) && ./$(REG50N_BINARIES_SOURCE:%.tar.bz2=%.sh) tar)
	mkdir -p $(@D)/files
	tar -xvjf $(@D)/$(REG50N_BINARIES_SOURCE) -C $(@D)/files/
endef

define REG50N_BINARIES_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 755 $(@D)/files/lru $(TARGET_DIR)/usr/bin/lru
	$(INSTALL) -D -m 755 $(@D)/files/smu_cli $(TARGET_DIR)/usr/bin/smu_cli
	$(INSTALL) -D -m 644 $(@D)/files/utf*.bin -t $(TARGET_DIR)/lib/firmware/ath6k/AR6004/hw3.0/
	$(INSTALL) -D -m 755 $(@D)/files/tcmd.sh $(TARGET_DIR)/usr/bin/tcmd.sh
endef

$(eval $(generic-package))
