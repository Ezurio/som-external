################################################################################
#
# python-awsiotsdk
#
################################################################################

PYTHON_AWSIOTSDK_VERSION = 1.21.0
PYTHON_AWSIOTSDK_SOURCE = awsiotsdk-$(PYTHON_AWSIOTSDK_VERSION).tar.gz
PYTHON_AWSIOTSDK_SITE = https://files.pythonhosted.org/packages/1c/7d/c143fe073625f2ea6a9d79f4198856beb100f7386ba709fbac88f85ec86e
PYTHON_AWSIOTSDK_SETUP_TYPE = setuptools
PYTHON_AWSIOTSDK_LICENSE = Apache-2.0

$(eval $(python-package))
