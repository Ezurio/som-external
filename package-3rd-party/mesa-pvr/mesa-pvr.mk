################################################################################
#
# mesa-pvr
#
################################################################################

# corresponds to branch powervr/24.0.1
MESA_PVR_VERSION = 7c82c1eebc67f5a62a347a84d42fe795cf7f523b
MESA_PVR_SOURCE = mesa-$(MESA_PVR_VERSION).tar.bz2
MESA_PVR_SITE = https://gitlab.freedesktop.org/StaticRocket/mesa/-/archive/$(MESA_PVR_VERSION)
MESA_PVR_LICENSE = MIT, SGI, Khronos
MESA_PVR_LICENSE_FILES = docs/license.rst
MESA_PVR_CVE_VERSION = 24.0.1
MESA_PVR_CPE_ID_VENDOR = mesa3d
MESA_PVR_CPE_ID_PRODUCT = mesa

MESA_PVR_INSTALL_STAGING = YES

MESA_PVR_PROVIDES =

MESA_PVR_DEPENDENCIES = \
	host-bison \
	host-flex \
	host-python-mako \
	expat \
	libdrm \
	zlib

MESA_PVR_CONF_OPTS = \
	-Dgallium-omx=disabled \
	-Dpower8=disabled \
	-Dvideo-codecs=

ifeq ($(BR2_PACKAGE_MESA_PVR_DRIVER)$(BR2_PACKAGE_XORG7),yy)
MESA_PVR_CONF_OPTS += -Ddri3=enabled
MESA_PVR_DEPENDENCIES += xlib_libxshmfence
else
MESA_PVR_CONF_OPTS += -Ddri3=disabled
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_LLVM),y)
MESA_PVR_DEPENDENCIES += host-llvm llvm
MESA_PVR_MESON_EXTRA_BINARIES += llvm-config='$(STAGING_DIR)/usr/bin/llvm-config'
MESA_PVR_CONF_OPTS += -Dllvm=enabled
ifeq ($(BR2_PACKAGE_LLVM_RTTI),y)
MESA_PVR_CONF_OPTS += -Dcpp_rtti=true
else
MESA_PVR_CONF_OPTS += -Dcpp_rtti=false
endif
else
# Avoid automatic search of llvm-config
MESA_PVR_CONF_OPTS += -Dllvm=disabled
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_NEEDS_ELFUTILS),y)
MESA_PVR_DEPENDENCIES += elfutils
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_OPENGL_GLX),y)
# Disable-mangling not yet supported by meson build system.
# glx:
#  dri          : dri based GLX requires at least one DRI driver || dri based GLX requires shared-glapi
#  xlib         : xlib conflicts with any dri driver
# Always enable glx-direct; without it, many GLX applications don't work.
MESA_PVR_CONF_OPTS += \
	-Dglx=dri \
	-Dglx-read-only-text=true \
	-Dglx-direct=true
ifeq ($(BR2_PACKAGE_MESA_PVR_NEEDS_XA),y)
MESA_PVR_CONF_OPTS += -Dgallium-xa=enabled
else
MESA_PVR_CONF_OPTS += -Dgallium-xa=disabled
endif
else
MESA_PVR_CONF_OPTS += \
	-Dglx=disabled \
	-Dgallium-xa=disabled
endif

# Drivers

#Gallium Drivers
MESA_PVR_GALLIUM_DRIVERS-$(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER_SWRAST)   += swrast
MESA_PVR_GALLIUM_DRIVERS-$(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER_VIRGL)    += virgl
MESA_PVR_GALLIUM_DRIVERS-$(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER_ZINK)     += zink
MESA_PVR_GALLIUM_DRIVERS-$(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER_ROGUE)    += pvr
MESA_PVR_GALLIUM_DRIVERS-$(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER_SGX)      += sgx

# Vulkan Drivers
MESA_PVR_VULKAN_DRIVERS-$(BR2_PACKAGE_MESA_PVR_VULKAN_DRIVER_SWRAST) += swrast
MESA_PVR_VULKAN_DRIVERS-$(BR2_PACKAGE_MESA_PVR_VULKAN_DRIVER_ROGUE)  += pvr

ifeq ($(BR2_PACKAGE_MESA_PVR_GALLIUM_DRIVER),)
MESA_PVR_CONF_OPTS += \
	-Dgallium-drivers= \
	-Dgallium-extra-hud=false
else
MESA_PVR_CONF_OPTS += \
	-Dshared-glapi=enabled \
	-Dgallium-drivers=$(subst $(space),$(comma),$(MESA_PVR_GALLIUM_DRIVERS-y)) \
	-Dgallium-extra-hud=true
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_VULKAN_DRIVER),)
MESA_PVR_CONF_OPTS += \
	-Dvulkan-drivers=
else
MESA_PVR_DEPENDENCIES += host-python-glslang
MESA_PVR_CONF_OPTS += \
	-Dvulkan-drivers=$(subst $(space),$(comma),$(MESA_PVR_VULKAN_DRIVERS-y))
endif

# APIs

ifeq ($(BR2_PACKAGE_MESA_PVR_OSMESA_GALLIUM),y)
MESA_PVR_CONF_OPTS += -Dosmesa=true
else
MESA_PVR_CONF_OPTS += -Dosmesa=false
endif

# Always enable OpenGL:
#   - Building OpenGL ES without OpenGL is not supported, so always keep opengl enabled.
MESA_PVR_CONF_OPTS += -Dopengl=true

# libva and MESA_PVR have a circular dependency
# we do not need libva support in MESA_PVR, therefore disable this option
MESA_PVR_CONF_OPTS += -Dgallium-va=disabled

# libGL is only provided for a full xorg stack, without libglvnd
ifeq ($(BR2_PACKAGE_MESA_PVR_OPENGL_GLX),y)
MESA_PVR_PROVIDES += $(if $(BR2_PACKAGE_LIBGLVND),,libgl)
else
define MESA_PVR_REMOVE_OPENGL_HEADERS
	rm -rf $(STAGING_DIR)/usr/include/GL/
endef

MESA_PVR_POST_INSTALL_STAGING_HOOKS += MESA_PVR_REMOVE_OPENGL_HEADERS
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_NEEDS_X11),y)
MESA_PVR_DEPENDENCIES += \
	xlib_libX11 \
	xlib_libXext \
	xlib_libXdamage \
	xlib_libXfixes \
	xlib_libXrandr \
	xlib_libXxf86vm \
	xorgproto \
	libxcb
MESA_PVR_PLATFORMS += x11
endif
ifeq ($(BR2_PACKAGE_WAYLAND),y)
MESA_PVR_DEPENDENCIES += wayland wayland-protocols
MESA_PVR_PLATFORMS += wayland
endif

MESA_PVR_CONF_OPTS += \
	-Dplatforms=$(subst $(space),$(comma),$(MESA_PVR_PLATFORMS))

ifeq ($(BR2_PACKAGE_MESA_PVR_GBM),y)
MESA_PVR_CONF_OPTS += \
	-Dgbm=enabled
else
MESA_PVR_CONF_OPTS += \
	-Dgbm=disabled
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_OPENGL_EGL),y)
MESA_PVR_PROVIDES += $(if $(BR2_PACKAGE_LIBGLVND),,libegl)
MESA_PVR_CONF_OPTS += \
	-Degl=enabled
else
MESA_PVR_CONF_OPTS += \
	-Degl=disabled
endif

ifeq ($(BR2_PACKAGE_MESA_PVR_OPENGL_ES),y)
MESA_PVR_PROVIDES += $(if $(BR2_PACKAGE_LIBGLVND),,libgles)
MESA_PVR_CONF_OPTS += -Dgles1=enabled -Dgles2=enabled
else
MESA_PVR_CONF_OPTS += -Dgles1=disabled -Dgles2=disabled
endif

ifeq ($(BR2_PACKAGE_VALGRIND),y)
MESA_PVR_CONF_OPTS += -Dvalgrind=enabled
MESA_PVR_DEPENDENCIES += valgrind
else
MESA_PVR_CONF_OPTS += -Dvalgrind=disabled
endif

ifeq ($(BR2_PACKAGE_LIBUNWIND),y)
MESA_PVR_CONF_OPTS += -Dlibunwind=enabled
MESA_PVR_DEPENDENCIES += libunwind
else
MESA_PVR_CONF_OPTS += -Dlibunwind=disabled
endif

ifeq ($(BR2_PACKAGE_LM_SENSORS),y)
MESA_PVR_CONF_OPTS += -Dlmsensors=enabled
MESA_PVR_DEPENDENCIES += lm-sensors
else
MESA_PVR_CONF_OPTS += -Dlmsensors=disabled
endif

ifeq ($(BR2_PACKAGE_ZSTD),y)
MESA_PVR_CONF_OPTS += -Dzstd=enabled
MESA_PVR_DEPENDENCIES += zstd
else
MESA_PVR_CONF_OPTS += -Dzstd=disabled
endif

MESA_PVR_CFLAGS = $(TARGET_CFLAGS)

# m68k needs 32-bit offsets in switch tables to build
ifeq ($(BR2_m68k),y)
MESA_PVR_CFLAGS += -mlong-jump-table-offsets
endif

ifeq ($(BR2_PACKAGE_LIBGLVND),y)
ifneq ($(BR2_PACKAGE_MESA_PVR_OPENGL_GLX)$(BR2_PACKAGE_MESA_PVR_OPENGL_EGL),)
MESA_PVR_DEPENDENCIES += libglvnd
MESA_PVR_CONF_OPTS += -Dglvnd=true
else
MESA_PVR_CONF_OPTS += -Dglvnd=false
endif
else
MESA_PVR_CONF_OPTS += -Dglvnd=false
endif

$(eval $(meson-package))
