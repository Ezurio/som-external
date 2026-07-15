################################################################################
#
# cst (NXP Code Signing Tool)
#
################################################################################

CST_VERSION = 4.0.1
CST_SOURCE = IMX_CST_TOOL_NEW.tgz

CST_URI ?= https://$(RFPROS_FILESHARE_AUTH)files.devops.rfpros.com/tools/nxp/cst/$(CST_VERSION)
CST_SITE = $(CST_URI)

CST_LICENSE = BSD-3-Clause, Apache-2.0, MIT, LGPL-2.1
CST_LICENSE_FILES = COPYING

CST_STRIP_COMPONENTS = 0

# CMakeLists.txt is in the src/ subdirectory of the release tarball.
CST_SUBDIR = cst-$(CST_VERSION)/src

HOST_CST_DEPENDENCIES = host-openssl host-json-c host-pkgconf

# Upstream code has unused-result warnings that trip -Werror.
HOST_CST_CONF_OPTS = \
	-DCMAKE_C_FLAGS="$(HOST_CFLAGS) -Wno-error=unused-result" \
	-DBUILD_SHARED_LIBS=OFF \
	-DCST_OPENSSL_SHARED=ON \
	-DCST_WITH_PKCS11=OFF \
	-DCST_WITH_PQC=OFF \
	-DBUILD_HAB_LOG_PARSER=OFF \
	-DBUILD_CST=ON \
	-DBUILD_SRKTOOL=ON \
	-DBUILD_XHAB_PKI_TREE=ON \
	-DBUILD_AHAB_SIGNED_MESSAGE=ON

$(eval $(host-cmake-package))
