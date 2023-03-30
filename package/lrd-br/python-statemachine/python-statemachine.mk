################################################################################
#
# python-statemachine
#
################################################################################

PYTHON_STATEMACHINE_VERSION = 2.0.0
PYTHON_STATEMACHINE_SOURCE = python_statemachine-$(PYTHON_STATEMACHINE_VERSION).tar.gz
PYTHON_STATEMACHINE_SITE = https://files.pythonhosted.org/packages/a6/9e/3ece63987db925f0decfb32212fc316ebaa9bb8321621805ea133ee4f559
PYTHON_STATEMACHINE_SETUP_TYPE = setuptools
PYTHON_STATEMACHINE_LICENSE = MIT
PYTHON_STATEMACHINE_LICENSE_FILES = LICENSE

$(eval $(python-package))
