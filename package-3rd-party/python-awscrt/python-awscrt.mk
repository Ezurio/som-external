################################################################################
#
# python-awscrt
#
################################################################################

PYTHON_AWSCRT_VERSION = 0.31.3
PYTHON_AWSCRT_SOURCE = awscrt-$(PYTHON_AWSCRT_VERSION).tar.gz
PYTHON_AWSCRT_SITE = https://files.pythonhosted.org/packages/3d/e7/354b811e17c0dc8641209446d39306667a34a5158fc8b2fb03333d1cb1a3
PYTHON_AWSCRT_SETUP_TYPE = setuptools
PYTHON_AWSCRT_LICENSE = Apache-2.0
PYTHON_AWSCRT_LICENSE_FILES = LICENSE crt/aws-c-common/LICENSE crt/aws-lc/LICENSE crt/aws-lc/third_party/fiat/LICENSE crt/aws-c-mqtt/LICENSE crt/aws-c-io/LICENSE crt/aws-c-sdkutils/LICENSE crt/s2n/LICENSE crt/aws-checksums/LICENSE crt/aws-c-cal/LICENSE crt/aws-c-auth/LICENSE crt/aws-c-s3/LICENSE crt/aws-c-event-stream/LICENSE crt/aws-c-http/LICENSE crt/aws-c-compression/LICENSE
PYTHON_AWSCRT_DEPENDENCIES = host-cmake host-openssl
PYTHON_AWSCRT_ENV = AWS_CRT_BUILD_USE_SYSTEM_LIBCRYPTO=1

$(eval $(python-package))
