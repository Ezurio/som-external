################################################################################
#
# python-spectree
#
################################################################################

PYTHON_SPECTREE_VERSION = 2.0.1
PYTHON_SPECTREE_SOURCE = spectree-$(PYTHON_SPECTREE_VERSION).tar.gz
PYTHON_SPECTREE_SITE = https://files.pythonhosted.org/packages/72/3d/1380581a90b714a56cb1669982e5889557b6edcda85e9ee3d538804f4726
PYTHON_SPECTREE_SETUP_TYPE = setuptools
PYTHON_SPECTREE_LICENSE = Apache-2.0
PYTHON_SPECTREE_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
