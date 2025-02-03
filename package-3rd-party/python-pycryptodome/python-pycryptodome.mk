################################################################################
#
# python-pycryptodome
#
################################################################################

PYTHON_PYCRYPTODOME_VERSION = 3.21.0
PYTHON_PYCRYPTODOME_SOURCE = pycryptodome-$(PYTHON_PYCRYPTODOME_VERSION).tar.gz
PYTHON_PYCRYPTODOME_SITE = https://files.pythonhosted.org/packages/13/52/13b9db4a913eee948152a079fe58d035bd3d1a519584155da8e786f767e6
PYTHON_PYCRYPTODOME_SETUP_TYPE = setuptools
PYTHON_PYCRYPTODOME_LICENSE = \
	BSD-2-Clause, \
	Public Domain (pycrypto original code)
PYTHON_PYCRYPTODOME_LICENSE_FILES = LICENSE.rst Doc/LEGAL/COPYRIGHT.pycrypto
PYTHON_PYCRYPTODOME_CPE_ID_VENDOR = pycryptodome
PYTHON_PYCRYPTODOME_CPE_ID_PRODUCT = pycryptodome

PYTHON_PYCRYPTODOME_ENV = CFLAGS="$(TARGET_CFLAGS) -std=c99"
HOST_PYTHON_PYCRYPTODOME_ENV = CFLAGS="$(HOST_CFLAGS) -std=c99"

$(eval $(python-package))
$(eval $(host-python-package))
