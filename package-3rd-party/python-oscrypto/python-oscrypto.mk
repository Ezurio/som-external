################################################################################
#
# python-oscrypto
#
################################################################################

PYTHON_OSCRYPTO_VERSION = 1.3.0
PYTHON_OSCRYPTO_SOURCE = oscrypto-$(PYTHON_OSCRYPTO_VERSION).tar.gz
PYTHON_OSCRYPTO_SITE = https://files.pythonhosted.org/packages/06/81/a7654e654a4b30eda06ef9ad8c1b45d1534bfd10b5c045d0c0f6b16fecd2
PYTHON_OSCRYPTO_SETUP_TYPE = setuptools
PYTHON_OSCRYPTO_LICENSE = MIT
PYTHON_OSCRYPTO_LICENSE_FILES = LICENSE
PYTHON_OSCRYPTO_DEPENDENCIES = openssl
HOST_PYTHON_OSCRYPTO_DEPENDENCIES = host-openssl

$(eval $(python-package))
$(eval $(host-python-package))
