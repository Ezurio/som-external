################################################################################
#
# python-pyserial
#
################################################################################

PYTHON_PYSERIAL_VERSION = 3.5
PYTHON_PYSERIAL_SOURCE = pyserial-$(PYTHON_PYSERIAL_VERSION).tar.gz
PYTHON_PYSERIAL_SITE = https://files.pythonhosted.org/packages/1e/7d/ae3f0a63f41e4d2f6cb66a5b57197850f919f59e558159a4dd3a818f5082
PYTHON_PYSERIAL_SETUP_TYPE = setuptools
PYTHON_PYSERIAL_LICENSE = BSD-3-Clause
PYTHON_PYSERIAL_LICENSE_FILES = LICENSE.txt

$(eval $(python-package))
$(eval $(host-python-package))
