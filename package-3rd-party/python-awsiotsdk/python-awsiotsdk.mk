################################################################################
#
# python-awsiotsdk
#
################################################################################

PYTHON_AWSIOTSDK_VERSION = 1.31.0
PYTHON_AWSIOTSDK_SOURCE = awsiotsdk-$(PYTHON_AWSIOTSDK_VERSION).tar.gz
PYTHON_AWSIOTSDK_SITE = https://files.pythonhosted.org/packages/08/d3/c78e8af41eff13d03b206e3f455fdd549eb115c563f91fcdb2b3faa5e7ee
PYTHON_AWSIOTSDK_SETUP_TYPE = setuptools
PYTHON_AWSIOTSDK_LICENSE = Apache-2.0

$(eval $(python-package))
