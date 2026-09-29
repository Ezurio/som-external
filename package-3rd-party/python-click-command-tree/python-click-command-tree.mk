################################################################################
#
# python-click-command-tree
#
################################################################################

PYTHON_CLICK_COMMAND_TREE_VERSION = 1.2.0
PYTHON_CLICK_COMMAND_TREE_SOURCE = click_command_tree-$(PYTHON_CLICK_COMMAND_TREE_VERSION).tar.gz
PYTHON_CLICK_COMMAND_TREE_SITE = https://files.pythonhosted.org/packages/95/47/fd73ca0ba632a9c45610839a493825834dd74fdc9e2e2d1ffc6416932161
PYTHON_CLICK_COMMAND_TREE_SETUP_TYPE = setuptools
PYTHON_CLICK_COMMAND_TREE_LICENSE = MIT
PYTHON_CLICK_COMMAND_TREE_LICENSE_FILES = LICENSE
PYTHON_CLICK_COMMAND_TREE_DEPENDENCIES = python-click
HOST_PYTHON_CLICK_COMMAND_TREE_DEPENDENCIES = host-python-click

$(eval $(python-package))
$(eval $(host-python-package))
