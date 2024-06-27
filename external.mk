# Summit branch number, update for every branch
export BR2_SUMMIT_BRANCH := 0

ifneq ($(VERSION),)
  export BR2_SUMMIT_BUILD_VERSION = $(VERSION)
else
  export BR2_SUMMIT_BUILD_VERSION = 0.$(BR2_SUMMIT_BRANCH).0.0
endif

ifneq ($(RFPROS_FILESHARE_USER),)
  RFPROS_FILESHARE_AUTH ?= ${RFPROS_FILESHARE_USER}:${RFPROS_FILESHARE_PASS}@
endif

export SUMMIT_SOM_URI_BASE_ARCHIVE  ?= https://github.com/LairdCP/wb-package-archive/releases/download/LRD-REL
export SUMMIT_SOM_URI_BASE_INTERNAL ?= https://${RFPROS_FILESHARE_AUTH}files.devops.rfpros.com/builds/linux

include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/toolchain/*/*.mk))
