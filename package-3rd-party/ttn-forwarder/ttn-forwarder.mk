################################################################################
#
# ttn-forwarder
#
################################################################################

TTN_FORWARDER_VERSION = v2.0.2
TTN_FORWARDER_SITE = https://github.com/TheThingsNetwork/packet_forwarder/archive
TTN_FORWARDER_SOURCE = $(TTN_FORWARDER_VERSION).tar.gz

TTN_FORWARDER_LICENSE = MIT
TTN_FORWARDER_LICENSE_FILES = LICENSE

TTN_FORWARDER_DEPENDENCIES = host-go

HOST_TTN_FORWARDER_MAKE_ENV = \
	GOARCH=amd64 \
	GOOS=linux \
	GOROOT="$(HOST_GO_ROOT)" \
	GOTOOLDIR="$(HOST_GO_TOOLDIR)" \
	GOBIN="" \
	CC=$(HOSTCC_NOCCACHE) \
	GOPATH="$(@D)/gopath"

TTN_FORWARDER_MAKE_ENV = \
	$(HOST_GO_TARGET_ENV) \
	$(if $(GO_GOARM),GOARM=$(GO_GOARM)) \
	GOBIN="$(@D)/bin" \
	GOPATH="$(@D)/gopath" \
	CGO_ENABLED=1

define HOST_TTN_FORWARDER_INSTALL_CMDS
	cd $(@D) && $(HOST_TTN_FORWARDER_MAKE_ENV) \
		$(HOST_DIR)/usr/bin/go get -v github.com/kardianos/govendor

	$(INSTALL) -D -m 0755 $(@D)/gopath/bin/govendor $(HOST_DIR)/usr/bin/govendor
endef
TTN_FORWARDER_PRE_EXTRACT_HOOKS += HOST_TTN_FORWARDER_INSTALL_CMDS

define TTN_FORWARDER_GET_DEPS
	# Put sources at prescribed GOPATH location.
	mkdir -p $(@D)/gopath/src/github.com/TheThingsNetwork
	ln -s $(@D) $(@D)/gopath/src/github.com/TheThingsNetwork/packet_forwarder

	# Pull in all requirements
	cd $(@D)/gopath/src/github.com/TheThingsNetwork/packet_forwarder && \
		$(TTN_FORWARDER_MAKE_ENV) $(TARGET_MAKE_ENV) $(MAKE) deps
endef
TTN_FORWARDER_POST_EXTRACT_HOOKS += TTN_FORWARDER_GET_DEPS

define TTN_FORWARDER_BUILD_CMDS

	cd $(@D)/gopath/src/github.com/TheThingsNetwork/packet_forwarder && \
		PLATFORM=$(BR2_TTN_FORWARDER_PLATFORM) \
		$(TTN_FORWARDER_MAKE_ENV) $(TARGET_MAKE_ENV) $(MAKE1) build

endef

define TTN_FORWARDER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/release/packet-forwarder-* $(TARGET_DIR)/usr/sbin/ttn_packet_forwarder
endef

$(eval $(generic-package))
$(eval $(host-generic-package))
