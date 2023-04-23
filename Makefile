ARCH_all = x86 x86_64 arm-eabi arm-eabihf aarch64 powerpc64-e5500 powerpc32
ARCH_lrd = arm-eabi arm-eabihf

MAKE_TARGETS = $(foreach t,$(TARGETS_COMPONENT_$(1)), $(addprefix $(t)-,$(ARCH_$(1))))

TARGETS_radio = \
	som60_rdvk wb50n_rdvk som60_lwb_mfg \
	wb40n_rdvk wb40n_rdvk_3_2 bdimx6_rdvk

TARGETS_toolchain = \
	som60_toolchain wb4x_toolchain bdimx6_toolchain wb40_32_toolchain

TARGETS_fips_dev = \
	wb50nsd_sysd_fips_dev wb45n_legacy_fips_dev \
	som60sd_fips_dev som60sd_fips_dev_dbg \
	wb50nsd_sysd_fips_dev_dbg wb45n_legacy_fips_dev_dbg

TARGETS_sysd = \
	wb50n_sysd wb50nsd_sysd wb50n_sysd_fips wb50nsd_sysd_fips \
	som60 som60sd som60sd_mfg som60_fips som60sd_fips \
	ig60ll ig60llsd

TARGETS_legacy = \
	wb50n_legacy wb45n_legacy \
	wb50n_legacy_fips wb45n_legacy_fips

TARGETS_wbx3 = \
	wb50nsd_sysd-wbx3 som60sd-wbx3 ig60sd-wbx3

TARGETS = \
    $(TARGETS_radio) $(TARGETS_toolchain) $(TARGETS_wbx3) \
	$(TARGETS_sysd) $(TARGETS_legacy) $(TARGETS_fips_dev) \
	som60sd_sdcsdk_nm

TARGETS_COMPONENT_all = mfg60n regLWB \
	summit_supplicant_libs \
	adaptive_ww adaptive_bt

TARGETS_COMPONENT_lrd = reg45n reg50n regCypress \
	laird_openssl_3_0_fips \
	summit_supplicant_libs_legacy

TARGETS_COMPONENT = \
	$(call MAKE_TARGETS,all) $(call MAKE_TARGETS,lrd) \
	backports backports-test firmware \
	regCypress-aarch64

TARGETS_COMPONENT_radio = $(filter-out %-powerpc32 adaptive_bt-% laird_openssl_% backports-test,$(TARGETS_COMPONENT))

TARGETS_SRC = summit_supplicant-src lrd-network-manager-src adaptive_bt-src linux-docs

#**************************************************************************

MK_DIR = $(realpath $(dir $(firstword $(MAKEFILE_LIST))))
BR_DIR = $(realpath $(MK_DIR)/../buildroot)

export BR2_EXTERNAL =

 TARGETS_SRC_CLEAN = $(addsuffix -clean,$(TARGETS_SRC))
.PHONY: $(TARGETS_SRC) $(TARGETS_SRC_CLEAN)

all:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_SRC)

clean:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_SRC_CLEAN)

.PHONY: radio-stack radio-stack-clean som som-clean \
	legacy legacy-clean wbx3 wbx3-clean fips-dev fips-dev-clean \
	toolchain toolchain-clean ssl ssl-clean

radio-stack:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_COMPONENT_radio) $(TARGETS_SRC)
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_radio) backports-test

radio-stack-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_COMPONENT_radio) $(TARGETS_radio) backports-test)

som:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_sysd)

som-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_sysd))

legacy:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_legacy)

legacy-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_legacy))

wbx3:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_wbx3)

wbx3-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_wbx3))

fips-dev:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_fips_dev)

fips-dev-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_fips_dev))

toolchain:
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_toolchain)

toolchain-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_toolchain))

ssl:
	$(MAKE) $(PARALLEL_OPTS) $(filter laird_openssl_%,$(TARGETS_COMPONENT))

ssl-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(filter laird_openssl_%,$(TARGETS_COMPONENT)))

ifneq ($(wildcard $(BR_DIR)/../som-external/build-rules.mk),)
include $(BR_DIR)/../som-external/build-rules.mk
endif

OUTPUT_DIR ?= $(abspath $(MK_DIR)/../buildroot/output)

LINUX_DOCS_SRC_DIR = $(MK_DIR)/../linux_docs
LINUX_DOCS_DST_DIR = $(OUTPUT_DIR)/linux-docs

ifneq ($(VERSION),)
RELEASE_SUFFIX = -$(VERSION)
endif

linux-docs:
	mkdir -p $(LINUX_DOCS_DST_DIR)/build $(LINUX_DOCS_DST_DIR)/images
	rm -rf $(LINUX_DOCS_DST_DIR)/build/*
	cp -rt $(LINUX_DOCS_DST_DIR)/build $(LINUX_DOCS_SRC_DIR)/60_series \
		$(LINUX_DOCS_SRC_DIR)/LWB $(LINUX_DOCS_SRC_DIR)/latex_templates \
		$(LINUX_DOCS_SRC_DIR)/LWB $(LINUX_DOCS_SRC_DIR)/Android

	$(MAKE) -C $(LINUX_DOCS_DST_DIR)/build/60_series all
	cd $(LINUX_DOCS_DST_DIR)/build/60_series && \
	tar -cjf $(LINUX_DOCS_DST_DIR)/images/laird-sterling-60-docs$(RELEASE_SUFFIX).tar.bz2 \
		--owner=root --group=root \
		app_note_*.pdf \
		sig_60_series_radio.pdf \
		user_guide_60_networkmanager.pdf \
		user_guide_60_dvk_su60_sipt.pdf

	$(MAKE) -C $(LINUX_DOCS_DST_DIR)/build/LWB all
	tar -cjf $(LINUX_DOCS_DST_DIR)/images/laird-sterling-lwb-docs$(RELEASE_SUFFIX).tar.bz2 \
		-C $(LINUX_DOCS_DST_DIR)/build/LWB \
		--owner=root --group=root \
		sig_LWB_series_radio.pdf \
		app_note_LWB_regtools.pdf

	$(MAKE) -C $(LINUX_DOCS_DST_DIR)/build/Android all
	cd $(LINUX_DOCS_DST_DIR)/build/Android && \
	tar -cjf $(LINUX_DOCS_DST_DIR)/images/laird-android-sig-docs$(RELEASE_SUFFIX).tar.bz2 \
		-C $(LINUX_DOCS_DST_DIR)/build/Android \
		--owner=root --group=root \
		*.pdf

lrd-network-manager-src:
	mkdir -p $(OUTPUT_DIR)/$@/images
	tar -C $(BR_DIR)/../som-external/package/lrd/externals/lrd-network-manager --exclude=.git \
		--transform "s,.,lrd-network-manager$(RELEASE_SUFFIX)," \
		--owner=root --group=root \
		-cJf $(OUTPUT_DIR)/$@/images/$@$(RELEASE_SUFFIX).tar.xz .

# NOTE, summit_supplicant-src excludes closed source laird directory
summit_supplicant-src:
ifeq ($(wildcard $(BR_DIR)/../lrd-closed-source-external/package/externals/wpa_supplicant/laird/libsdcsupp),)
	$(error "Cannot create summit_supplicant-src -- not opensource")
else
	mkdir -p $(OUTPUT_DIR)/$@/images
	tar -C $(BR_DIR)/../lrd-closed-source-external/package/externals/wpa_supplicant --exclude=.git --exclude=laird \
		--transform "s,^,summit_supplicant$(RELEASE_SUFFIX)/," \
		--owner=root --group=root \
		-czf $(OUTPUT_DIR)/$@/images/$@$(RELEASE_SUFFIX).tar.gz \
		README COPYING CONTRIBUTIONS src wpa_supplicant hs20 hostapd
endif

adaptive_bt-src:
	mkdir -p $(OUTPUT_DIR)/$@/images
	tar -C $(BR_DIR)/../som-external/package/lrd/externals/adaptive_bt --exclude=.git \
		--transform "s,^,adaptive_bt$(RELEASE_SUFFIX)/," \
		--owner=root --group=root \
		-czf $(OUTPUT_DIR)/$@/images/$@$(RELEASE_SUFFIX).tar.gz \
		Makefile include src support

$(TARGETS_SRC_CLEAN): %-clean:
	rm -rf $(OUTPUT_DIR)/$*
