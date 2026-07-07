################################################################################
#
# python-fastjsonschema
#
################################################################################

PYTHON_FASTJSONSCHEMA_VERSION = 2.21.1
PYTHON_FASTJSONSCHEMA_SOURCE = fastjsonschema-$(PYTHON_FASTJSONSCHEMA_VERSION).tar.gz
PYTHON_FASTJSONSCHEMA_SITE = https://files.pythonhosted.org/packages/source/f/fastjsonschema
PYTHON_FASTJSONSCHEMA_SETUP_TYPE = setuptools
PYTHON_FASTJSONSCHEMA_LICENSE = BSD-3-Clause
PYTHON_FASTJSONSCHEMA_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
