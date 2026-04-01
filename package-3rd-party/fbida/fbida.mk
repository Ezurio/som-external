################################################################################
#
# fbida
#
################################################################################

FBIDA_VERSION = a0d75fbab3ea01bf5b36f813f0ec0d1bfa2db745
FBIDA_SITE = $(call github,kraxel,fbida,$(FBIDA_VERSION))
FBIDA_LICENSE = GPL-2.0
FBIDA_LICENSE_FILES = COPYING

FBIDA_DEPENDENCIES = jpeg udev cairo libinput libdrm libexif libxkbcommon \
	$(if $(BR2_PACKAGE_FBIDA_GIF),giflib,) \
	$(if $(BR2_PACKAGE_FBIDA_PNG),libpng,) \
	$(if $(BR2_PACKAGE_FBIDA_TIFF),libtiff,) \
	$(if $(BR2_PACKAGE_FBIDA_WEBP),webp,) \
	$(if $(BR2_PACKAGE_FBIDA_PDF),poppler,) \
	$(if $(BR2_PACKAGE_SYSTEMD),systemd,)

FBIDA_CONF_OPTS = \
	-Dgif=$(if $(BR2_PACKAGE_FBIDA_GIF),enabled,disabled) \
	-Dpng=$(if $(BR2_PACKAGE_FBIDA_PNG),enabled,disabled) \
	-Dtiff=$(if $(BR2_PACKAGE_FBIDA_TIFF),enabled,disabled) \
	-Dwebp=$(if $(BR2_PACKAGE_FBIDA_WEBP),enabled,disabled) \
	-Dpdf=$(if $(BR2_PACKAGE_FBIDA_PDF),enabled,disabled)

FBIDA_CONF_ENV = $(TARGET_CONFIGURE_OPTS)

$(eval $(meson-package))
