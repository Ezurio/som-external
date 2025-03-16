################################################################################
#
# mesa3d-headers
#
################################################################################

# mesa3d-headers is inherently incompatible with mesa3d, so error out
# if both are enabled.
ifeq ($(BR_BUILDING)$(BR2_PACKAGE_MESA_PVR)$(BR2_PACKAGE_MESA_PVR_HEADERS),yyy)
$(error mesa-pvr-headers enabled, but mesa-pvr enabled too)
endif

# Not possible to directly refer to mesa3d variables, because of
# first/second expansion trickery...
MESA_PVR_HEADERS_VERSION = 82e6a9293c476267417c5b6b906b01fb73a34e38
MESA_PVR_SOURCE = mesa-$(MESA_PVR_HEADERS_VERSION).tar.bz2
MESA_PVR_HEADERS_SITE = https://gitlab.freedesktop.org/StaticRocket/mesa/-/archive/$(MESA_PVR_VERSION)
MESA_PVR_HEADERS_DL_SUBDIR = mesa3d
MESA_PVR_HEADERS_LICENSE = MIT, SGI, Khronos
MESA_PVR_HEADERS_LICENSE_FILES = docs/license.rst
MESA_PVR_HEADERS_CVE_VERSION = 24.0.1
MESA_PVR_HEADERS_CPE_ID_VENDOR = mesa3d
MESA_PVR_HEADERS_CPE_ID_PRODUCT = mesa

# Only installs header files
MESA_PVR_HEADERS_INSTALL_STAGING = YES
MESA_PVR_HEADERS_INSTALL_TARGET = NO

MESA_PVR_HEADERS_DIRS = KHR

ifeq ($(BR2_PACKAGE_HAS_LIBGL),y)

MESA_PVR_HEADERS_DIRS += GL

ifeq ($(BR2_PACKAGE_XORG7),y)

# Not using $(SED) because we do not want to work in-place, and $(SED)
# contains -i.
define MESA_PVR_HEADERS_BUILD_DRI_PC
	sed -e 's:@VERSION@:$(MESA_PVR_HEADERS_VERSION):' \
		$(MESA_PVR_HEADERS_PKGDIR)/dri.pc \
		>$(@D)/src/gallium/frontends/dri/dri.pc
endef

define MESA_PVR_HEADERS_INSTALL_DRI_PC
	$(INSTALL) -D -m 0644 $(@D)/include/GL/internal/dri_interface.h \
		$(STAGING_DIR)/usr/include/GL/internal/dri_interface.h
	$(INSTALL) -D -m 0644 $(@D)/src/gallium/frontends/dri/dri.pc \
		$(STAGING_DIR)/usr/lib/pkgconfig/dri.pc
endef

endif # Xorg

endif # OpenGL

ifeq ($(BR2_PACKAGE_HAS_LIBEGL),y)
MESA_PVR_HEADERS_DIRS += EGL
endif

ifeq ($(BR2_PACKAGE_HAS_LIBGLES),y)
MESA_PVR_HEADERS_DIRS += GLES GLES2
endif

ifeq ($(BR2_PACKAGE_HAS_LIBOPENCL),y)
MESA_PVR_HEADERS_DIRS += CL
endif

define MESA_PVR_HEADERS_BUILD_CMDS
	$(MESA_PVR_HEADERS_BUILD_DRI_PC)
endef

define MESA_PVR_HEADERS_INSTALL_STAGING_CMDS
	$(foreach d,$(MESA_PVR_HEADERS_DIRS),\
		cp -dpfr $(@D)/include/$(d) $(STAGING_DIR)/usr/include/ || exit 1$(sep))
	$(MESA_PVR_HEADERS_INSTALL_DRI_PC)
endef

$(eval $(generic-package))
