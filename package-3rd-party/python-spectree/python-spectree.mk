################################################################################
#
# python-spectree
#
################################################################################

PYTHON_SPECTREE_VERSION = 1.4.5
PYTHON_SPECTREE_SOURCE = spectree-$(PYTHON_SPECTREE_VERSION).tar.gz
PYTHON_SPECTREE_SITE = https://files.pythonhosted.org/packages/e4/59/39737351c04c387fc7d867516e42a8e48d79f6b63aaac6c9d147b0f6707a
PYTHON_SPECTREE_SETUP_TYPE = setuptools
PYTHON_SPECTREE_LICENSE = Apache-2.0
PYTHON_SPECTREE_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
