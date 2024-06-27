# Summit branch number, update for every branch
export BR2_LRD_BRANCH := 10

export RFPROS_FILESHARE_AUTH ?= $(if $(RFPROS_FILESHARE_USER),$(RFPROS_FILESHARE_USER):$(RFPROS_FILESHARE_PASS)@,)

include $(sort $(wildcard $(BR2_EXTERNAL_LRD_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_LRD_SOM_PATH)/toolchain/*/*.mk))
