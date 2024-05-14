################################################################################
#
# lora-gateway-bridge
#
################################################################################

LORA_GATEWAY_BRIDGE_VERSION = 2.1.5
LORA_GATEWAY_BRIDGE_SITE = $(call github,chirpstack,chirpstack-gateway-bridge)
LORA_GATEWAY_BRIDGE_LICENSE = MIT
LORA_GATEWAY_BRIDGE_LICENSE_FILES = LICENSE

LORA_GATEWAY_BRIDGE_DEPENDENCIES = host-go

LORA_GATEWAY_BRIDGE_MAKE_ENV = \
	$(HOST_GO_TARGET_ENV) \
	$(if $(GO_GOARM),GOARM=$(GO_GOARM)) \
	GOBIN="$(@D)/bin" \
	GOPATH="$(@D)/gopath" \
	CGO_ENABLED=1

define LORA_GATEWAY_BRIDGE_BUILD_CMDS
	# Put sources at prescribed GOPATH location.
	mkdir -p $(@D)/gopath/src/github.com/brocaar
	ln -s $(@D) $(@D)/gopath/src/github.com/brocaar/lora-gateway-bridge

	cd $(@D)/gopath/src/github.com/brocaar/lora-gateway-bridge && \
		$(LORA_GATEWAY_BRIDGE_MAKE_ENV) $(TARGET_MAKE_ENV) $(MAKE1) build
endef

define LORA_GATEWAY_BRIDGE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/build/lora-gateway-bridge $(TARGET_DIR)/usr/sbin/lora-gateway-bridge
endef

$(eval $(generic-package))
