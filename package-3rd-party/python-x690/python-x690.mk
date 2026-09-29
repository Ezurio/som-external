################################################################################
#
# python-x690
#
################################################################################

PYTHON_X690_VERSION = 1.0.0
PYTHON_X690_SOURCE = x690-$(PYTHON_X690_VERSION).tar.gz
PYTHON_X690_SITE = https://files.pythonhosted.org/packages/14/9a/50a737b5c0453e13b2cb8e2c2c0343af3353cd9a294a08e5efac32ad31fd
PYTHON_X690_SETUP_TYPE = setuptools
PYTHON_X690_LICENSE = MIT
PYTHON_X690_LICENSE_FILES = LICENSE.txt
PYTHON_X690_DEPENDENCIES = python-t61codec
HOST_PYTHON_X690_DEPENDENCIES = host-python-t61codec

$(eval $(python-package))
$(eval $(host-python-package))
