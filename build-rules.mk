# Generic Make engine for customer builds
# Customer external repositories should be using this Makefile

vigiles_name := $(realpath $(BR_DIR)/../vigiles-buildroot)

BR2_EXTERNAL += \
	$(realpath $(MK_DIR)) \
	$(realpath $(BR_DIR)/../som-external) \
	$(realpath $(BR_DIR)/../lrd-closed-source-external) \
	$(vigiles_name)

export BR2_EXTERNAL := $(sort $(BR2_EXTERNAL))

CONFIG_DIR ?= $(realpath $(MK_DIR)/configs)
OUTPUT_DIR ?= $(abspath $(BR_DIR)/output)

TARGETS_ALL = $(TARGETS) $(TARGETS_COMPONENT)

ifeq ($(VERSION),)
release_name = $(1)$(BR2_LRD_BUILD_SUFFIX)-laird
else
release_name = $(1)$(BR2_LRD_BUILD_SUFFIX)-laird-$(VERSION)
endif

release_file = $(OUTPUT_DIR)/$(1)/images/$(call release_name,$(1)).tar

ifeq ($(PARALLEL_JOBS),)
PARALLEL_JOBS := $(shell echo $$((1 + `nproc 2>/dev/null || echo 0`)))
else ifeq ($(PARALLEL_JOBS),0)
PARALLEL_JOBS := $(shell echo $$((1 + `nproc 2>/dev/null || echo 0`)))
endif

PARALLEL_OPTS = -j$(PARALLEL_JOBS) PARALLEL_JOBS=$(PARALLEL_JOBS)
ifneq ($(PARALLEL_JOBS),1)
PARALLEL_OPTS += -Orecurse
endif

.PHONY: all clean
all:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_ALL)

clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_ALL))

$(patsubst %,$(OUTPUT_DIR)/%/.config,$(TARGETS_ALL)): $(OUTPUT_DIR)/%/.config: $(CONFIG_DIR)/%_defconfig
	$(MAKE) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* $*_defconfig

.PHONY: $(TARGETS_ALL)
$(TARGETS_ALL): %: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$*
ifneq ($(VIGILES_DASHBOARD_CONFIG),)
ifneq ($(vigiles_name),)
	$(MAKE) -C $(OUTPUT_DIR)/$* vigiles-check
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

.PHONY: $(addsuffix -sdk,$(TARGETS))
$(addsuffix -sdk,$(TARGETS)): %-sdk: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* BR2_SDK_PREFIX=$@ sdk

.PHONY: $(addsuffix -legal-info,$(TARGETS_ALL))
$(addsuffix -legal-info,$(TARGETS_ALL)): %-legal-info: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* legal-info
	tar --exclude=*sources -C $(OUTPUT_DIR)/$*/legal-info/ \
		--owner=0 --group=0 --numeric-owner \
		-cjf $(OUTPUT_DIR)/$*/images/legal-info.tar.bz2 .

.PHONY: $(addsuffix -vigiles,$(TARGETS))
$(addsuffix -vigiles,$(TARGETS)): %-vigiles:
ifneq ($(vigiles_name),)
	$(MAKE) -C $(OUTPUT_DIR)/$* vigiles-check
endif

.PHONY: $(addsuffix -full,$(TARGETS))
$(addsuffix -full,$(TARGETS)): %-full: % %-legal-info %-sdk
	bzip2 -d $(call release_file,$*).bz2
	tar -C $(OUTPUT_DIR)/$*/images -rf $(call release_file,$*) \
		--owner=0 --group=0 --numeric-owner \
		legal-info.tar.bz2 $*-sdk.tar.gz
	bzip2 $(call release_file,$*)

.PHONY: $(addsuffix -full-legal,$(TARGETS))
$(addsuffix -full-legal,$(TARGETS)): %-full-legal: % %-legal-info
	bzip2 -d $(call release_file,$*).bz2
	tar -C "$(OUTPUT_DIR)/$*/images" -rf $(call release_file,$*) \
		--owner=0 --group=0 --numeric-owner \
		legal-info.tar.bz2
	bzip2 $(call release_file,$*)

.PHONY: $(addsuffix -sdk-only,$(TARGETS))
$(addsuffix -sdk-only,$(TARGETS)): %-sdk-only: $(OUTPUT_DIR)/%/.config
	$(MAKE) $(PARALLEL_OPTS) -C $(BR_DIR) O=$(OUTPUT_DIR)/$* BR2_SDK_PREFIX=$(call release_name,$*) sdk
	sha256sum $(call release_file,$*).gz | sed 's, .*/, ,' > $(call release_file,$*).gz.sha
