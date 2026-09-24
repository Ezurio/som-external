################################################################################
#
# python-prettytable
#
################################################################################

PYTHON_PRETTYTABLE_VERSION = 3.16.0
PYTHON_PRETTYTABLE_SOURCE = prettytable-$(PYTHON_PRETTYTABLE_VERSION).tar.gz
PYTHON_PRETTYTABLE_SITE = https://files.pythonhosted.org/packages/99/b1/85e18ac92afd08c533603e3393977b6bc1443043115a47bb094f3b98f94f
PYTHON_PRETTYTABLE_SETUP_TYPE = hatch
PYTHON_PRETTYTABLE_LICENSE = BSD-3-Clause
PYTHON_PRETTYTABLE_LICENSE_FILES = LICENSE
HOST_PYTHON_PRETTYTABLE_DEPENDENCIES = \
	host-python-hatch-vcs \
	host-python-hatchling \
	host-python-pyparsing

$(eval $(host-python-package))
