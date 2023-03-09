# Summit branch number, update for every branch
export BR2_LRD_BRANCH := 0

include $(sort $(wildcard $(BR2_EXTERNAL_LRD_SOM_PATH)/package/*/*.mk))
include $(sort $(wildcard $(BR2_EXTERNAL_LRD_SOM_PATH)/toolchain/*/*.mk))
