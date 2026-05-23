################################################################################
#
# summit-rcm-rust
#
################################################################################

SUMMIT_RCM_RUST_VERSION = local
SUMMIT_RCM_RUST_SITE = $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/externals/summit-rcm-rust
SUMMIT_RCM_RUST_SITE_METHOD = local

SUMMIT_RCM_RUST_LICENSE = Ezurio
SUMMIT_RCM_RUST_LICENSE_FILES = LICENSE.ezurio

SUMMIT_RCM_RUST_DEPENDENCIES = openssl

# ---------------------------------------------------------------------------
# Build up --features list from Kconfig options.
# Always pass --no-default-features so the Cargo defaults don't surprise us.
# ---------------------------------------------------------------------------

SUMMIT_RCM_RUST_FEATURES = \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_V2_ROUTES),api-v2,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_LEGACY_ROUTES),api-legacy,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_AT_INTERFACE),at-interface,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_DATE_TIME),date-time,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_FILES),files,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_LOGIN),login,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_LOGS),logs,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_NETWORK),network,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_NETWORK_MANAGER),network-manager,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_SYSTEM),system,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_UPDATE),update,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_AWM),awm,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_BLUETOOTH),bluetooth,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_BLUETOOTH_VSP),bluetooth-vsp,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_BLUETOOTH_HID),bluetooth-hid,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_BLUETOOTH_WEBSOCKET),bluetooth-websocket,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_CHRONY),chrony,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_FIPS),fips,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_FIREWALL),firewall,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_LOG_FORWARDING),log-forwarding,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_PROVISIONING),provisioning,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_RADIO_SISO_MODE),radio-siso-mode,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_STUNNEL),stunnel,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_PLUGIN_UNAUTHENTICATED),unauthenticated,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_DOCS_RUNTIME),runtime-docs swagger-ui api-docs,) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_DOCS_JSON),runtime-docs swagger-ui,)

SUMMIT_RCM_RUST_DOC_GEN_FEATURES = \
	$(filter-out runtime-docs swagger-ui api-docs,$(SUMMIT_RCM_RUST_FEATURES)) \
	$(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_DOCS_JSON),api-docs,)

# Space-separated → comma-separated for cargo --features
SUMMIT_RCM_RUST_FEATURES_CSV = $(subst $(space),$(comma),$(strip $(SUMMIT_RCM_RUST_FEATURES)))
SUMMIT_RCM_RUST_DOC_GEN_FEATURES_CSV = $(subst $(space),$(comma),$(strip $(SUMMIT_RCM_RUST_DOC_GEN_FEATURES)))

SUMMIT_RCM_RUST_CARGO_BUILD_OPTS = --no-default-features
ifneq ($(strip $(SUMMIT_RCM_RUST_FEATURES)),)
SUMMIT_RCM_RUST_CARGO_BUILD_OPTS += --features $(SUMMIT_RCM_RUST_FEATURES_CSV)
endif

SUMMIT_RCM_RUST_CARGO_INSTALL_OPTS = $(SUMMIT_RCM_RUST_CARGO_BUILD_OPTS) --profile release

# Rust still embeds source locations used by panic and tracing metadata in
# .rodata even for stripped release binaries. Remap the package build root so
# shipped artifacts do not expose absolute Buildroot paths.
SUMMIT_RCM_RUST_CARGO_ENV += \
	RUSTFLAGS="--remap-path-prefix=$(SUMMIT_RCM_RUST_SRCDIR)=."

# ---------------------------------------------------------------------------
# Install target hooks
# ---------------------------------------------------------------------------

define SUMMIT_RCM_RUST_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/usr/lib/systemd/system \
		$(SUMMIT_RCM_RUST_PKGDIR)/summit-rcm.service
endef

define SUMMIT_RCM_RUST_INSTALL_CONFIG
	$(INSTALL) -d $(TARGET_DIR)/etc/summit-rcm

	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc \
		$(SUMMIT_RCM_RUST_PKGDIR)/summit-rcm.ini \

	$(INSTALL) -D -m 644 -t $(TARGET_DIR)/etc/summit-rcm/ssl \
		$(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/rest-server/server.key \
		$(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/rest-server/server.crt \
		$(BR2_EXTERNAL_SUMMIT_SOM_PATH)/board/configs-common/keys/rest-server/ca.crt

	$(INSTALL) -D -m 755 -t $(TARGET_DIR)/sbin \
		$(SUMMIT_RCM_PKGDIR)/factory_powerup_summit-rcm.sh

	# --- [global] TLS settings ---
	$(SED) '/^server\.ssl_certificate/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^server\.ssl_private_key/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^server\.ssl_certificate_chain/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[global\]/a server.ssl_certificate: $(BR2_PACKAGE_SUMMIT_RCM_RUST_SERVER_SSL_CERTIFICATE)' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[global\]/a server.ssl_private_key: $(BR2_PACKAGE_SUMMIT_RCM_RUST_SERVER_SSL_PRIVATE_KEY)' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[global\]/a server.ssl_certificate_chain: $(BR2_PACKAGE_SUMMIT_RCM_RUST_SERVER_SSL_CERTIFICATE_CHAIN)' $(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] session settings ---
	$(SED) 's,^tools\.sessions\.on:.*,tools.sessions.on: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_ENABLE_SESSIONS),True,False),' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^default_username/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^default_password/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a default_username: $(BR2_PACKAGE_SUMMIT_RCM_RUST_DEFAULT_USERNAME)' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a default_password: $(BR2_PACKAGE_SUMMIT_RCM_RUST_DEFAULT_PASSWORD)' $(TARGET_DIR)/etc/summit-rcm.ini

	$(SED) '/^allow_multiple_user_sessions/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a allow_multiple_user_sessions: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_ALLOW_MULTIPLE_USER_SESSIONS),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] network device lists ---
	$(SED) '/^managed_software_devices/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a managed_software_devices: $(BR2_PACKAGE_SUMMIT_RCM_RUST_MANAGED_SOFTWARE_DEVICES)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^unmanaged_hardware_devices/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a unmanaged_hardware_devices: $(BR2_PACKAGE_SUMMIT_RCM_RUST_UNMANAGED_HARDWARE_DEVICES)' \
		$(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] client authentication ---
	$(SED) '/^enable_client_auth/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a enable_client_auth: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_ENABLE_CLIENT_AUTHENTICATION),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^disable_certificate_expiry_verification/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a disable_certificate_expiry_verification: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_DISABLE_CERTIFICATE_EXPIRY_VERIFICATION),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^enable_client_pairing/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a enable_client_pairing: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_ENABLE_CLIENT_PAIRING),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^paired_client_cert_path/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a paired_client_cert_path: $(BR2_PACKAGE_SUMMIT_RCM_RUST_PAIRED_CLIENT_CERT_PATH)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^rodata_ca_cert_path/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a rodata_ca_cert_path: $(BR2_PACKAGE_SUMMIT_RCM_RUST_RODATA_CA_CERT_PATH)' \
		$(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] REST API misc ---
	$(SED) '/^log_routes_loaded/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a log_routes_loaded: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_LOG_ROUTES_LOADED),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^network_status_restricted/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a network_status_restricted: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_RESTRICT_NETWORK_STATUS),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^socket_port/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a socket_port: $(BR2_PACKAGE_SUMMIT_RCM_RUST_HTTPS_PORT)' \
		$(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] OpenAPI docs ---
	$(SED) '/^rest_api_docs/d' $(TARGET_DIR)/etc/summit-rcm.ini
	rm -f $(TARGET_DIR)/etc/summit-rcm-openapi.json
	$(SED) '/^rest_api_docs_root_redirect/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a rest_api_docs_root_redirect: $(if $(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_DOCS_ROOT_REDIRECT),true,false)' \
		$(TARGET_DIR)/etc/summit-rcm.ini

	# --- [summit-rcm] AT interface ---
	$(SED) '/^serial_port/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a serial_port: $(BR2_PACKAGE_SUMMIT_RCM_RUST_SERIAL_PORT)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/^baud_rate/d' $(TARGET_DIR)/etc/summit-rcm.ini
	$(SED) '/\[summit-rcm\]/a baud_rate: $(BR2_PACKAGE_SUMMIT_RCM_RUST_BAUD_RATE)' \
		$(TARGET_DIR)/etc/summit-rcm.ini
endef

SUMMIT_RCM_RUST_POST_INSTALL_TARGET_HOOKS += SUMMIT_RCM_RUST_INSTALL_CONFIG

ifeq ($(BR2_PACKAGE_SUMMIT_RCM_RUST_REST_API_DOCS_JSON),y)
define SUMMIT_RCM_RUST_GENERATE_OPENAPI_DOC
	cd $(SUMMIT_RCM_RUST_SRCDIR) && \
		RUSTFLAGS="--remap-path-prefix=$(SUMMIT_RCM_RUST_SRCDIR)=." \
		SUMMIT_RCM_OPENAPI_OUTPUT="$(TARGET_DIR)/etc/summit-rcm-openapi.json" \
		$(HOST_DIR)/bin/cargo run \
			--release \
			--bin generate_openapi \
			--no-default-features \
			--features "$(SUMMIT_RCM_RUST_DOC_GEN_FEATURES_CSV)"
endef

SUMMIT_RCM_RUST_POST_INSTALL_TARGET_HOOKS += SUMMIT_RCM_RUST_GENERATE_OPENAPI_DOC
endif

$(eval $(cargo-package))
