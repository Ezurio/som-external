################################################################################
#
# python-click-option-group
#
################################################################################

PYTHON_CLICK_OPTION_GROUP_VERSION = 0.5.6
PYTHON_CLICK_OPTION_GROUP_SOURCE = click-option-group-$(PYTHON_CLICK_OPTION_GROUP_VERSION).tar.gz
PYTHON_CLICK_OPTION_GROUP_SITE = https://files.pythonhosted.org/packages/e7/b8/91054601a2e05fd9060cb1baf56be5b24145817b059e078669e1099529c7
PYTHON_CLICK_OPTION_GROUP_SETUP_TYPE = setuptools
PYTHON_CLICK_OPTION_GROUP_LICENSE = BSD-3-Clause
PYTHON_CLICK_OPTION_GROUP_LICENSE_FILES = LICENSE
PYTHON_CLICK_OPTION_GROUP_DEPENDENCIES = python-click
HOST_PYTHON_CLICK_OPTION_GROUP_DEPENDENCIES = host-python-click

$(eval $(python-package))
$(eval $(host-python-package))
