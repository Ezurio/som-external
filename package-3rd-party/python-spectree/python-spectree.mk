################################################################################
#
# python-spectree
#
################################################################################

PYTHON_SPECTREE_VERSION = 1.2.10
PYTHON_SPECTREE_SOURCE = spectree-$(PYTHON_SPECTREE_VERSION).tar.gz
PYTHON_SPECTREE_SITE = https://files.pythonhosted.org/packages/4e/a6/ae66f91c210d15fa99582d1bf4cb6998971978613c813c5c2bcb2e2ab65c
PYTHON_SPECTREE_SETUP_TYPE = setuptools
PYTHON_SPECTREE_LICENSE = Apache-2.0
PYTHON_SPECTREE_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
