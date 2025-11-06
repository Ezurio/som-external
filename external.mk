# Summit branch number, update for every branch
export BR2_SUMMIT_BRANCH := 0

export BR2_SUMMIT_BUILD_VERSION = $(if $(VERSION),$(VERSION),0.$(BR2_SUMMIT_BRANCH).0.0)
export SUMMIT_SOM_SW_DESCRIPTION = $(call qstrip,$(BR2_SUMMIT_SW_DESCRIPTION))

RFPROS_FILESHARE_AUTH ?= $(if $(RFPROS_FILESHARE_USER),$(RFPROS_FILESHARE_USER):$(RFPROS_FILESHARE_PASS)@,)

export SUMMIT_SOM_URI_BASE_ARCHIVE  ?= https://github.com/Ezurio/wb-package-archive/releases/download/LRD-REL
export SUMMIT_SOM_URI_BASE_INTERNAL ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/builds/linux

ifeq ($(KEY_PATH),)
ifneq ($(SECURE_TARGET_BUILD),)
$(error KEY_PATH is not set for secure target build)
else
ifeq ($(findstring am6,$(BR2_ROOTFS_POST_SCRIPT_ARGS)),am6)
KEY_PATH := $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/carbon/keys/dev.key
else
KEY_PATH := $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/dev.key
endif
endif
endif

ifeq ("$(wildcard $(KEY_PATH))","")
$(error Key file not found: $(KEY_PATH))
endif

export KEY_PATH

KEYS_DIR := $(dir $(KEY_PATH))

ifeq ("$(wildcard $(KEYS_DIR))","")
$(error Keys directory not found: $(KEYS_DIR))
endif

export KEYS_DIR

include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/toolchain/*/*.mk))
