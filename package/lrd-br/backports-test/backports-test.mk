################################################################################
#
# backports regression test
#
################################################################################


BACKPORTS_TEST_VERSION = $(call qstrip,$(BR2_PACKAGE_LINUX_BACKPORTS_VERSION))
ifeq ($(BACKPORTS_TEST_VERSION),)
BACKPORTS_TEST_VERSION = 0.$(BR2_LRD_BRANCH).0.0
endif

BACKPORTS_TEST_SOURCE = backports-laird-$(BACKPORTS_TEST_VERSION).tar.bz2
BR_NO_CHECK_HASH_FOR += $(BACKPORTS_TEST_SOURCE)
BACKPORTS_TEST_LICENSE = GPL-2.0
BACKPORTS_TEST_LICENSE_FILES = COPYING
BACKPORTS_TEST_SITE_METHOD = wget
HOST_BACKPORTS_TEST_DEPENDENCIES = \
	$(BR2_BISON_HOST_DEPENDENCY) \
	$(BR2_FLEX_HOST_DEPENDENCY) \
	host-zstd

BACKPORTS_TEST_TOOLDIR = $(BR2_EXTERNAL_LRD_SOM_PATH)/package/lrd/externals/backports/devel

ifeq ($(MSD_BINARIES_SOURCE_LOCATION),laird_internal)
  BACKPORTS_TEST_SITE = https://files.devops.rfpros.com/builds/linux/backports/laird/$(BACKPORTS_TEST_VERSION)
else
  BACKPORTS_TEST_SITE = https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL-$(BACKPORTS_TEST_VERSION)
endif

define HOST_BACKPORTS_TEST_BUILD_CMDS
	$(HOST_MAKE_ENV) $(BACKPORTS_TEST_TOOLDIR)/backports-update-manager --yes --lrd-repo
	cd $(@D); $(HOST_CONFIGURE_OPTS) $(BACKPORTS_TEST_TOOLDIR)/ckmake --defconfig=regression-test --nocurses
endef

$(eval $(host-generic-package))
