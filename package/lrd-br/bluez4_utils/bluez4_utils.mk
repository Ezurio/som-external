################################################################################
#
# bluez_utils
#
################################################################################

BLUEZ4_UTILS_VERSION = 4.101
BLUEZ4_UTILS_SOURCE = bluez-$(BLUEZ4_UTILS_VERSION).tar.xz
BLUEZ4_UTILS_SITE = $(BR2_KERNEL_MIRROR)/linux/bluetooth
BLUEZ4_UTILS_INSTALL_STAGING = YES
BLUEZ4_UTILS_DEPENDENCIES = host-pkgconf check dbus libglib2
BLUEZ4_UTILS_CONF_OPTS = --enable-test --enable-tools
BLUEZ4_UTILS_AUTORECONF = YES
BLUEZ4_UTILS_LICENSE = GPL-2.0+, LGPL-2.1+
BLUEZ4_UTILS_LICENSE_FILES = COPYING COPYING.LIB

# BlueZ 3.x compatibility
ifeq ($(BR2_PACKAGE_BLUEZ4_UTILS_COMPAT),y)
BLUEZ4_UTILS_CONF_OPTS += \
	--enable-hidd \
	--enable-pand \
	--enable-sdp \
	--enable-dund
endif

# audio support
ifeq ($(BR2_PACKAGE_BLUEZ4_UTILS_AUDIO),y)
BLUEZ4_UTILS_DEPENDENCIES += \
	alsa-lib \
	libsndfile
BLUEZ4_UTILS_CONF_OPTS += \
	--enable-alsa \
	--enable-audio
else
BLUEZ4_UTILS_CONF_OPTS += \
	--disable-alsa \
	--disable-audio
endif

ifeq ($(BR2_PACKAGE_BLUEZ4_UTILS_GATT),y)
BLUEZ4_UTILS_DEPENDENCIES += readline
BLUEZ4_UTILS_CONF_OPTS += --enable-gatt
else
BLUEZ4_UTILS_CONF_OPTS += --disable-gatt
endif

# USB support
ifeq ($(BR2_PACKAGE_BLUEZ4_UTILS_USB),y)
BLUEZ4_UTILS_DEPENDENCIES += libusb
BLUEZ4_UTILS_CONF_OPTS += \
	--enable-usb
else
BLUEZ4_UTILS_CONF_OPTS += \
	--disable-usb
endif

ifeq ($(BR2_TOOLCHAIN_SUPPORTS_PIE),)
BLUEZ4_UTILS_CONF_OPTS += --disable-pie
endif

$(eval $(autotools-package))
