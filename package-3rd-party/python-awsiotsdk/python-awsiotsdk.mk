################################################################################
#
# python-awsiotsdk
#
################################################################################

PYTHON_AWSIOTSDK_VERSION = 1.22.2
PYTHON_AWSIOTSDK_SOURCE = awsiotsdk-$(PYTHON_AWSIOTSDK_VERSION).tar.gz
PYTHON_AWSIOTSDK_SITE = https://files.pythonhosted.org/packages/82/ac/317fa29880d365980deae80b3edbf060a1686972c86f5fa92a2616bd621c
PYTHON_AWSIOTSDK_SETUP_TYPE = setuptools
PYTHON_AWSIOTSDK_LICENSE = Apache-2.0

$(eval $(python-package))
