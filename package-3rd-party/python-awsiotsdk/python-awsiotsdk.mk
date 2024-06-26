################################################################################
#
# python-awsiotsdk
#
################################################################################

PYTHON_AWSIOTSDK_VERSION = 1.21.5
PYTHON_AWSIOTSDK_SOURCE = awsiotsdk-$(PYTHON_AWSIOTSDK_VERSION).tar.gz
PYTHON_AWSIOTSDK_SITE = https://files.pythonhosted.org/packages/ed/68/60302d214beff245e9faeac29a7f4e2c8a63c385fa264176917b361784a6
PYTHON_AWSIOTSDK_SETUP_TYPE = setuptools
PYTHON_AWSIOTSDK_LICENSE = Apache-2.0

$(eval $(python-package))
