################################################################################
#
# python-awsiotsdk
#
################################################################################

PYTHON_AWSIOTSDK_VERSION = 1.30.0
PYTHON_AWSIOTSDK_SOURCE = awsiotsdk-$(PYTHON_AWSIOTSDK_VERSION).tar.gz
PYTHON_AWSIOTSDK_SITE = https://files.pythonhosted.org/packages/9d/02/7340313e57aa69180deb8c6f4c7ea9887609d2012c22fc4e05d08d20e5e9
PYTHON_AWSIOTSDK_SETUP_TYPE = setuptools
PYTHON_AWSIOTSDK_LICENSE = Apache-2.0

$(eval $(python-package))
