# Generic Make engine for customer builds
# Customer external repositories should be using this Makefile

external_name = $(realpath $(BR_DIR)/../$(1))

BR2_EXTERNAL += \
	$(realpath $(MK_DIR)) \
	$(call external_name,som-external) \
	$(call external_name,summit-radio-external) \
	$(call external_name,summit-radio-devel-external) \
	$(call external_name,vigiles-buildroot)

export BR2_EXTERNAL := $(sort $(BR2_EXTERNAL))

CONFIG_DIR ?= $(realpath $(MK_DIR)/configs)
OUTPUT_DIR ?= $(abspath $(BR_DIR)/../output)

TARGETS_ALL = $(TARGETS) $(TARGETS_COMPONENT)

BR2_SUMMIT_BRANCH ?= $(shell sed -rn 's/.*BR2_SUMMIT_BRANCH :?= ([0-9]+).*/\1/p' $(call external_name,som-external/external.mk))
BR2_SUMMIT_BUILD_VERSION ?= $(if $(VERSION),$(VERSION),0.$(BR2_SUMMIT_BRANCH).0.0)

release_name = $(1)$(BR2_SUMMIT_BUILD_SUFFIX)-summit-$(BR2_SUMMIT_BUILD_VERSION)
release_file = $(OUTPUT_DIR)/$(1)/images/$(call release_name,$(1)).tar

ifeq ($(filter-out 0,$(strip $(PARALLEL_JOBS))),)
PARALLEL_JOBS := $(shell echo $$((1 + `nproc 2>/dev/null || echo 0`)))
endif

ifneq ($(PARALLEL_JOBS),1)
ifeq ($(strip $(filter %-menuconfig,$(MAKECMDGOALS))),)
PARALLEL_OPTS = -j$(PARALLEL_JOBS) PARALLEL_JOBS=$(PARALLEL_JOBS)
MAKEFLAGS += -Orecurse --no-print-directory
endif
endif

.PHONY: all clean savedefconfig
all:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_ALL)

clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_ALL))

savedefconfig:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -savedefconfig,$(TARGETS_ALL))
	$(MAKE) $(PARALLEL_OPTS) clean

$(patsubst %,$(OUTPUT_DIR)/%/.config,$(TARGETS_ALL)): $(OUTPUT_DIR)/%/.config: $(CONFIG_DIR)/%_defconfig
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* $*_defconfig

.PHONY: $(TARGETS_ALL)
$(TARGETS_ALL): %: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$*
ifneq ($(VIGILES_DASHBOARD_CONFIG),)
ifneq ($(call external_name,vigiles-buildroot),)
	$(MAKE) -C $(OUTPUT_DIR)/$* vigiles-check || true
endif
endif

.PHONY: $(addsuffix -menuconfig,$(TARGETS_ALL))
$(addsuffix -menuconfig,$(TARGETS_ALL)): %-menuconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* menuconfig

.PHONY: $(addsuffix -savedefconfig,$(TARGETS_ALL))
$(addsuffix -savedefconfig,$(TARGETS_ALL)): %-savedefconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* savedefconfig \
		BR2_DEFCONFIG=$(CONFIG_DIR)/$*_defconfig

.PHONY: $(addsuffix -linux-menuconfig,$(TARGETS))
$(addsuffix -linux-menuconfig,$(TARGETS)): %-linux-menuconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* linux-menuconfig

.PHONY: $(addsuffix -linux-savedefconfig,$(TARGETS))
$(addsuffix -linux-savedefconfig,$(TARGETS)): %-linux-savedefconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* linux-update-defconfig || \
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* linux-savedefconfig

.PHONY: $(addsuffix -uboot-menuconfig,$(TARGETS))
$(addsuffix -uboot-menuconfig,$(TARGETS)): %-uboot-menuconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* uboot-menuconfig

.PHONY: $(addsuffix -uboot-savedefconfig,$(TARGETS))
$(addsuffix -uboot-savedefconfig,$(TARGETS)): %-uboot-savedefconfig: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* uboot-update-defconfig || \
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* uboot-savedefconfig

.PHONY: $(addsuffix -clean,$(TARGETS_ALL))
$(addsuffix -clean,$(TARGETS_ALL)): %-clean:
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* distclean
	rm -rf $(OUTPUT_DIR)/$*

.PHONY: $(addsuffix -source,$(TARGETS))
$(addsuffix -source,$(TARGETS)): %-source: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* source

.PHONY: $(addsuffix -sdk,$(TARGETS))
$(addsuffix -sdk,$(TARGETS)): %-sdk: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* BR2_SDK_PREFIX=$@ sdk

.PHONY: $(addsuffix -legal-info,$(TARGETS_ALL))
$(addsuffix -legal-info,$(TARGETS_ALL)): %-legal-info: $(OUTPUT_DIR)/%/.config
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* legal-info
	tar --exclude=*sources -C $(OUTPUT_DIR)/$*/legal-info/ \
		--owner=root --group=root \
		-cjf $(OUTPUT_DIR)/$*/images/legal-info.tar.bz2 .

.PHONY: $(addsuffix -vigiles,$(TARGETS))
$(addsuffix -vigiles,$(TARGETS)): %-vigiles:
ifneq ($(call external_name,vigiles-buildroot),)
	$(MAKE) -C $(OUTPUT_DIR)/$* vigiles-check || true
endif

.PHONY: $(addsuffix -full,$(TARGETS))
$(addsuffix -full,$(TARGETS)): %-full: % %-legal-info %-sdk
	bzip2 -d $(call release_file,$*).bz2
	tar -C $(OUTPUT_DIR)/$*/images -rSf $(call release_file,$*) \
		--owner=root --group=root \
		legal-info.tar.bz2 $*-sdk.tar.gz
	bzip2 $(call release_file,$*)

.PHONY: $(addsuffix -full-legal,$(TARGETS))
$(addsuffix -full-legal,$(TARGETS)): %-full-legal: % %-legal-info
	bzip2 -d $(call release_file,$*).bz2
	tar -C "$(OUTPUT_DIR)/$*/images" -rSf $(call release_file,$*) \
		--owner=root --group=root \
		legal-info.tar.bz2
	bzip2 $(call release_file,$*)

.PHONY: $(addsuffix -sdk-only,$(TARGETS))
$(addsuffix -sdk-only,$(TARGETS)): %-sdk-only: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* BR2_SDK_PREFIX=$(call release_name,$*) sdk
