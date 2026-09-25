################################################################################
# aws-sdk-cpp
################################################################################
AWS_SDK_CPP_VERSION = 1.11.887
AWS_SDK_CPP_SITE = $(call github,aws,aws-sdk-cpp,$(AWS_SDK_CPP_VERSION))
AWS_SDK_CPP_LICENSE = Apache-2.0
AWS_SDK_CPP_LICENSE_FILES = LICENSE

HOST_AWS_SDK_CPP_DEPENDENCIES = host-openssl
AWS_SDK_CPP_DEPENDENCIES = openssl
AWS_SDK_CPP_INSTALL_STAGING = YES

HOST_AWS_SDK_CPP_CONF_OPTS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_ONLY="kms;acm-pca" \
	-DENABLE_TESTING=OFF \
	-DBUILD_SHARED_LIBS=OFF \
	-DUSE_CRT_HTTP_CLIENT=ON

AWS_SDK_CPP_CONF_OPTS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_ONLY="kms;acm-pca" \
	-DENABLE_TESTING=OFF \
	-DBUILD_SHARED_LIBS=ON \
	-DUSE_CRT_HTTP_CLIENT=ON

define AWS_SDK_CPP_CMAKE_MOVE_HOOK
	cd $(@D) && ./prefetch_crt_dependency.sh
    mkdir $(@D)/build
endef

HOST_AWS_SDK_CPP_PRE_CONFIGURE_HOOKS += AWS_SDK_CPP_CMAKE_MOVE_HOOK
AWS_SDK_CPP_PRE_CONFIGURE_HOOKS += AWS_SDK_CPP_CMAKE_MOVE_HOOK

$(eval $(cmake-package))
$(eval $(host-cmake-package))
