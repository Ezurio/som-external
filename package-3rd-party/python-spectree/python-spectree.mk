################################################################################
#
# python-spectree
#
################################################################################

PYTHON_SPECTREE_VERSION = 1.2.9
PYTHON_SPECTREE_SOURCE = spectree-$(PYTHON_SPECTREE_VERSION).tar.gz
PYTHON_SPECTREE_SITE = https://files.pythonhosted.org/packages/79/b6/6aaa4636cc61efc5af7fe875b15b0d5a3233d7e6da1704c18c6a7fb0f437
PYTHON_SPECTREE_SETUP_TYPE = setuptools
PYTHON_SPECTREE_LICENSE = Apache-2.0
PYTHON_SPECTREE_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
