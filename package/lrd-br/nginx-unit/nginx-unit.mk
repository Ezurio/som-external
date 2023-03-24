################################################################################
#
# nginx-unit
#
################################################################################

NGINX_UNIT_VERSION = 1.29.1
NGINX_UNIT_SITE = $(call github,nginx,unit,$(NGINX_UNIT_VERSION))
NGINX_UNIT_LICENSE = Apache-2.0
NGINX_UNIT_LICENSE_FILES = LICENSE
NGINX_UNIT_CPE_ID_VENDOR = nginx
NGINX_UNIT_DEPENDENCIES = host-pkgconf

NGINX_UNIT_CONF_OPTS = \
	--cc="$(TARGET_CC)" \
	--ld-opt="$(TARGET_LDFLAGS)"

NGINX_UNIT_CONF_ENV += \
	nxt_force_gcc_have_atomic=yes

NGINX_UNIT_CONF_OPTS += \
	--force-endianness=$(call qstrip,$(call LOWERCASE,$(BR2_ENDIAN))) \
	--user=www-data \
	--group=www-data \
	--control=unix:/tmp/control.unit.sock \
	--bindir=/sbin/bin \
	--sbindir=/sbin \
	--log=/var/log/nginx-unit.log \
	--modules=/etc/nginx-unit/modules \
	--pid=/var/run/unit.pid \
	--state=/etc/nginx-unit/state \
	--tmp=/tmp

ifeq ($(BR2_PACKAGE_OPENSSL),y)
NGINX_UNIT_DEPENDENCIES += openssl
NGINX_UNIT_CONF_OPTS += --openssl
ifeq ($(BR2_PACKAGE_LAIRD_OPENSSL_FIPS_BINARIES),y)
NGINX_UNIT_CONF_ENV += \
	OPENSSL_VERSION=$(LAIRD_OPENSSL_FIPS_BINARIES_CVE_VERSION)
else ifeq ($(BR2_PACKAGE_LIBOPENSSL_1_0_2),y)
NGINX_UNIT_CONF_ENV += \
	OPENSSL_VERSION=$(LIBOPENSSL_1_0_2_CVE_VERSION)
else ifeq ($(BR2_PACKAGE_LIBOPENSSL_3_0),y)
NGINX_UNIT_CONF_ENV += \
	OPENSSL_VERSION=$(LIBOPENSSL_3_0_VERSION)
else ifeq ($(BR2_PACKAGE_LIBOPENSSL),y)
NGINX_UNIT_CONF_ENV += \
	OPENSSL_VERSION=$(LIBOPENSSL_VERSION)
endif
endif

ifeq ($(BR2_PACKAGE_PCRE2),y)
NGINX_UNIT_DEPENDENCIES += pcre2
else ifeq ($(BR2_PACKAGE_PCRE),y)
NGINX_UNIT_DEPENDENCIES += pcre
NGINX_UNIT_CONF_OPTS += --no-pcre2
else
NGINX_UNIT_CONF_OPTS += --no-regex
endif

ifeq ($(BR2_PACKAGE_NGINX_UNIT_PYTHON_APP),y)
NGINX_UNIT_DEPENDENCIES += python3
NGINX_UNIT_CONF_ENV += \
	PYTHON3_VERSION=$(PYTHON3_VERSION) \
	PYTHON3_VERSION_MAJOR=$(PYTHON3_VERSION_MAJOR) \

define NGINX_UNIT_CONFIGURE_CMDS_PYTHON
	cd $(@D) ; \
		$(NGINX_UNIT_CONF_ENV) \
		$(TARGET_CONFIGURE_OPTS) \
		./configure python \
		--lib-path="$(TARGET_DIR)/lib/libpython$(PYTHON3_VERSION_MAJOR).so" \
		--config="$(TARGET_DIR)/usr/bin/python$(PYTHON3_VERSION_MAJOR)-config"
endef
endif

define NGINX_UNIT_CONFIGURE_CMDS
	cd $(@D) ; \
		$(NGINX_UNIT_CONF_ENV) \
		$(TARGET_CONFIGURE_OPTS) \
		./configure $(NGINX_UNIT_CONF_OPTS) \
			--cc-opt="$(TARGET_CFLAGS) $(NGINX_UNIT_CFLAGS)"
	$(NGINX_UNIT_CONFIGURE_CMDS_PYTHON)
endef

define NGINX_UNIT_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)
endef

define NGINX_UNIT_INSTALL_TARGET_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) DESTDIR=$(TARGET_DIR)/ install
endef

# systemd service file renamed to match package name
define NGINX_UNIT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(@D)/pkg/deb/debian/unit.service \
		$(TARGET_DIR)/usr/lib/systemd/system/nginx-unit.service
endef

$(eval $(generic-package))
