################################################################################
#
# python-httptools
#
################################################################################

PYTHON_HTTPTOOLS_VERSION = 0.6.1
PYTHON_HTTPTOOLS_SOURCE = httptools-$(PYTHON_HTTPTOOLS_VERSION).tar.gz
PYTHON_HTTPTOOLS_SITE = https://files.pythonhosted.org/packages/67/1d/d77686502fced061b3ead1c35a2d70f6b281b5f723c4eff7a2277c04e4a2
PYTHON_HTTPTOOLS_SETUP_TYPE = setuptools
PYTHON_HTTPTOOLS_LICENSE = MIT
PYTHON_HTTPTOOLS_LICENSE_FILES = LICENSE

$(eval $(python-package))
