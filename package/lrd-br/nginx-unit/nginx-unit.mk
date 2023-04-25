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
NGINX_UNIT_CPE_ID_PRODUCT = unit
NGINX_UNIT_DEPENDENCIES = host-pkgconf

NGINX_UNIT_CONF_OPTS += \
	--force-endianness=$(call qstrip,$(call LOWERCASE,$(BR2_ENDIAN))) \
	--user=root \
	--group=root \
	--control=unix:/tmp/control.unit.sock \
	--bindir=/sbin/bin \
	--sbindir=/sbin \
	--log=/var/log/nginx-unit.log \
	--modules=/etc/nginx-unit/modules \
	--pid=/run/unit.pid \
	--state=/etc/nginx-unit/state \
	--tmp=/tmp

ifeq ($(BR2_PACKAGE_OPENSSL),y)
NGINX_UNIT_DEPENDENCIES += openssl
NGINX_UNIT_CONF_OPTS += --openssl
else ifeq ($(BR2_PACKAGE_GNUTLS),y)
NGINX_UNIT_DEPENDENCIES += gnutls
NGINX_UNIT_CONF_OPTS += --gnutls
endif

ifeq ($(BR2_PACKAGE_PCRE2),y)
NGINX_UNIT_DEPENDENCIES += pcre2
else ifeq ($(BR2_PACKAGE_PCRE),y)
NGINX_UNIT_DEPENDENCIES += pcre
NGINX_UNIT_CONF_OPTS += --no-pcre2
else
NGINX_UNIT_CONF_OPTS += --no-regex
endif

ifeq ($(BR2_PACKAGE_LRD_ENCRYPTED_STORAGE_TOOLKIT),y)
NGINX_UNIT_CONF_OPTS += --open-certs-readonly
endif

ifeq ($(BR2_PACKAGE_NGINX_UNIT_PYTHON_APP),y)
NGINX_UNIT_DEPENDENCIES += python3

define NGINX_UNIT_CONFIGURE_CMDS_PYTHON
	cd $(@D) ; $(TARGET_CONFIGURE_OPTS) ./configure python
endef
endif

define NGINX_UNIT_CONFIGURE_CMDS
	cd $(@D) ; $(TARGET_CONFIGURE_OPTS) ./configure $(NGINX_UNIT_CONF_OPTS)
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
