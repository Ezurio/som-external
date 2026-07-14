################################################################################
# aws-sdk-cpp
################################################################################
AWS_SDK_CPP_VERSION = 1.11.845
AWS_SDK_CPP_SITE_METHOD = git
AWS_SDK_CPP_SITE = https://github.com/aws/aws-sdk-cpp.git
HOST_AWS_SDK_CPP_DEPENDENCIES = host-cmake host-openssl host-util-linux
AWS_SDK_CPP_LICENSE = Apache-2.0
AWS_SDK_CPP_LICENSE_FILES = LICENSE
AWS_SDK_CPP_SUPPORTS_IN_SOURCE_BUILD = NO

HOST_AWS_SDK_CPP_CONF_OPTS += \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_ONLY="kms;acm-pca" \
	-DENABLE_TESTING=OFF \
	-DBUILD_SHARED_LIBS=OFF \
	-DUSE_CRT_HTTP_CLIENT=ON

define AWS_SDK_CPP_CMAKE_MOVE_HOOK
	cd $(@D) && ./prefetch_crt_dependency.sh
    mkdir $(@D)/build
endef

HOST_AWS_SDK_CPP_PRE_CONFIGURE_HOOKS += AWS_SDK_CPP_CMAKE_MOVE_HOOK

$(eval $(host-cmake-package))
