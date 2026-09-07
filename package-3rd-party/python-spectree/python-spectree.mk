################################################################################
#
# python-spectree
#
################################################################################

PYTHON_SPECTREE_VERSION = 2.0.3
PYTHON_SPECTREE_SOURCE = spectree-$(PYTHON_SPECTREE_VERSION).tar.gz
PYTHON_SPECTREE_SITE = https://files.pythonhosted.org/packages/6e/a5/d498abca011f9ecf55f240536d0d61aa6381902f4c62255ad6ad7a80f983
PYTHON_SPECTREE_SETUP_TYPE = setuptools
PYTHON_SPECTREE_LICENSE = Apache-2.0
PYTHON_SPECTREE_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
