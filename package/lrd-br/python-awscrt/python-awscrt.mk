################################################################################
#
# python-awscrt
#
################################################################################

PYTHON_AWSCRT_VERSION = 0.20.4
PYTHON_AWSCRT_SOURCE = awscrt-$(PYTHON_AWSCRT_VERSION).tar.gz
PYTHON_AWSCRT_SITE = https://files.pythonhosted.org/packages/d4/26/85dcf6daa533d942dc7cd60152b664440f23aeefaaee27800e2e192af6dd
PYTHON_AWSCRT_SETUP_TYPE = setuptools
PYTHON_AWSCRT_LICENSE = Apache-2.0
PYTHON_AWSCRT_LICENSE_FILES = LICENSE crt/aws-c-common/LICENSE crt/aws-lc/LICENSE crt/aws-lc/third_party/fiat/LICENSE crt/aws-c-mqtt/LICENSE crt/aws-c-io/LICENSE crt/aws-c-sdkutils/LICENSE crt/s2n/LICENSE crt/aws-checksums/LICENSE crt/aws-c-cal/LICENSE crt/aws-c-auth/LICENSE crt/aws-c-s3/LICENSE crt/aws-c-event-stream/LICENSE crt/aws-c-http/LICENSE crt/aws-c-compression/LICENSE
PYTHON_AWSCRT_DEPENDENCIES = host-cmake host-openssl
PYTHON_AWSCRT_ENV = AWS_CRT_BUILD_USE_SYSTEM_LIBCRYPTO=1

$(eval $(python-package))
