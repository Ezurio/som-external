################################################################################
#
# lora-packet-forwarder
#
################################################################################

LORA_PACKET_FORWARDER_VERSION = v3.1.0
LORA_PACKET_FORWARDER_SITE = $(call github,Lora-net,packet_forwarder,$(LORA_PACKET_FORWARDER_VERSION))
LORA_PACKET_FORWARDER_LICENSE = BSD-3-Clause, MIT
LORA_PACKET_FORWARDER_LICENSE_FILES = LICENSE

LORA_PACKET_FORWARDER_DEPENDENCIES = libloragw

define  LORA_PACKET_FORWARDER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(TARGET_CONFIGURE_OPTS) LGW_PATH="$(STAGING_DIR)/usr/lib/libloragw" $(MAKE) -C $(@D)
endef

define LORA_PACKET_FORWARDER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -t $(TARGET_DIR)/usr/sbin -m 755 $(@D)/lora_pkt_fwd/lora_pkt_fwd
	$(INSTALL) -D -t $(TARGET_DIR)/opt/lora -m 644 $(@D)/lora_pkt_fwd/*.json
	$(INSTALL) -D -m 755 $(@D)/lora_pkt_fwd/update_gwid.sh $(TARGET_DIR)/usr/sbin/update_gwid
endef

define LORA_PACKET_FORWARDER_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/etc/init.d $(LORA_PACKET_FORWARDER_PKGDIR)/S95lora_pkt_fwd
endef

$(eval $(generic-package))
