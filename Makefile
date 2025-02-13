TARGETS_meta-toolchain = \
	som60_toolchain wb4x_toolchain imx8_toolchain

TARGETS_meta-som = \
	wb50n_sysd wb50nsd_sysd wb50n_sysd_fips wb50n_sysd_fips_11 \
	som60 som60sd som60sd_mfg som60sd_sdcsdk_nm \
	som60_fips som60sd_fips som60_fips_11 som60sd_fips_11 \
	ig60ll ig60llsd carbon_am62x carbon_am62x-mfg

TARGETS_meta-legacy = \
	wb50n_legacy wb45n_legacy \
	wb50n_legacy_fips wb45n_legacy_fips wb45n_legacy_fips_11

TARGETS_meta-wbx3 = \
	wb50nsd_sysd-wbx3 wb50nsd_legacy-wbx3 som60sd-wbx3 ig60sd-wbx3 \
	carbon_am62x-wbx3

TARGETS = \
	$(foreach t,som legacy wbx3 toolchain,$(TARGETS_meta-$(t)))

#**************************************************************************

MK_DIR = $(realpath $(dir $(firstword $(MAKEFILE_LIST))))
BR_DIR = $(realpath $(MK_DIR)/../buildroot)

include $(MK_DIR)/build-rules.mk

TARGETS_META = $(addprefix meta-,som legacy wbx3 toolchain)
TARGETS_META_CLEAN = $(addsuffix -clean,$(TARGETS_META))

.PHONY: $(TARGETS_SRC) $(TARGETS_SRC_CLEAN) \
	$(TARGETS_META) $(TARGETS_META_CLEAN)

all: $(TARGETS_META)

clean: $(TARGETS_META_CLEAN)

$(TARGETS_META):
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_$@)

$(TARGETS_META_CLEAN): %-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_$*))
