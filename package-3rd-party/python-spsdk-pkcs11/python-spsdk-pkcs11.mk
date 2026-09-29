################################################################################
#
# host-python-spsdk-pkcs11
#
################################################################################

PYTHON_SPSDK_PKCS11_VERSION = 0.3.8
PYTHON_SPSDK_PKCS11_SOURCE = spsdk_pkcs11-$(PYTHON_SPSDK_PKCS11_VERSION).tar.gz
PYTHON_SPSDK_PKCS11_SITE = https://files.pythonhosted.org/packages/source/s/spsdk-pkcs11
PYTHON_SPSDK_PKCS11_SETUP_TYPE = setuptools
PYTHON_SPSDK_PKCS11_LICENSE = BSD-3-Clause
PYTHON_SPSDK_PKCS11_LICENSE_FILES = LICENSE

PYTHON_SPSDK_PKCS11_DEPENDENCIES = \
	python-pkcs11 \
	python-cached-property \
	python-spsdk

HOST_PYTHON_SPSDK_PKCS11_DEPENDENCIES = \
	host-python-pkcs11 \
	host-python-cached-property \
	host-python-spsdk

$(eval $(python-package))
$(eval $(host-python-package))
