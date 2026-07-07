################################################################################
#
# python-deepmerge
#
################################################################################

PYTHON_DEEPMERGE_VERSION = 2.0
PYTHON_DEEPMERGE_SOURCE = deepmerge-$(PYTHON_DEEPMERGE_VERSION).tar.gz
PYTHON_DEEPMERGE_SITE = https://files.pythonhosted.org/packages/source/d/deepmerge
PYTHON_DEEPMERGE_SETUP_TYPE = setuptools
PYTHON_DEEPMERGE_LICENSE = MIT
PYTHON_DEEPMERGE_LICENSE_FILES = LICENSE
PYTHON_DEEPMERGE_DEPENDENCIES = host-python-setuptools-scm
HOST_PYTHON_DEEPMERGE_DEPENDENCIES = host-python-setuptools-scm

$(eval $(python-package))
$(eval $(host-python-package))
