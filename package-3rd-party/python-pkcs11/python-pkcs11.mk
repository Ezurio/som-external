################################################################################
#
# python-pkcs11
#
################################################################################

PYTHON_PKCS11_VERSION = 0.10.0
PYTHON_PKCS11_SOURCE = python_pkcs11-$(PYTHON_PKCS11_VERSION).tar.gz
PYTHON_PKCS11_SITE = https://files.pythonhosted.org/packages/source/p/python-pkcs11
PYTHON_PKCS11_SETUP_TYPE = setuptools
PYTHON_PKCS11_LICENSE = MIT
PYTHON_PKCS11_LICENSE_FILES = LICENSE

HOST_PYTHON_PKCS11_DEPENDENCIES = \
	host-python-asn1crypto \
	host-python-cython \
	host-python-setuptools-scm

$(eval $(host-python-package))
