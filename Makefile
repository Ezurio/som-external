TARGETS_meta-som = \
	wb50n_sysd wb50nsd_sysd wb50n_sysd_fips_11 \
	som60 som60_dev som60sd som60sd_sdcsdk_nm \
	som60_fips_11 som60sd_fips_11 \
	ig60ll ig60llsd \
	carbon_am62x carbon_am67x carbon_secure_am62x carbon_secure_am67x \
	summitsom_imx8mp summitsom_secure_imx8mp \
	nitrogen_imx91 nitrogen_imx93 nitrogen_imx95 \
	nitrogen_imx8mm_1g nitrogen_imx8mm_2g nitrogen_imx8mm_4g \
	nitrogen_imx8mp_2g_r1 nitrogen_imx8mp_2g_r2 nitrogen_imx8mp_4g \
	nitrogen_imx8mp_8g \
	nitrogen_secure_imx8mm_1g nitrogen_secure_imx8mm_2g \
	nitrogen_secure_imx8mm_4g \
	nitrogen_secure_imx8mp_2g_r1 nitrogen_secure_imx8mp_2g_r2 \
	nitrogen_secure_imx8mp_4g nitrogen_secure_imx8mp_8g

TARGETS_meta-legacy = \
	wb50n_legacy wb45n_legacy wb45n_legacy_fips_11

TARGETS = \
	$(foreach t,som legacy,$(TARGETS_meta-$(t)))

#**************************************************************************

MK_DIR = $(realpath $(dir $(firstword $(MAKEFILE_LIST))))
BR_DIR = $(realpath $(MK_DIR)/../buildroot)

include $(MK_DIR)/build-rules.mk

TARGETS_META = $(addprefix meta-,som legacy)
TARGETS_META_CLEAN = $(addsuffix -clean,$(TARGETS_META))

.PHONY: $(TARGETS_SRC) $(TARGETS_SRC_CLEAN) \
	$(TARGETS_META) $(TARGETS_META_CLEAN)

all: $(TARGETS_META)

clean: $(TARGETS_META_CLEAN)

$(TARGETS_META):
	$(MAKE) $(PARALLEL_OPTS) $(TARGETS_$@)

$(TARGETS_META_CLEAN): %-clean:
	$(MAKE) $(PARALLEL_OPTS) $(addsuffix -clean,$(TARGETS_$*))
