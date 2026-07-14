################################################################################
#
# python-httptools
#
################################################################################

PYTHON_HTTPTOOLS_VERSION = 0.8.0
PYTHON_HTTPTOOLS_SOURCE = httptools-$(PYTHON_HTTPTOOLS_VERSION).tar.gz
PYTHON_HTTPTOOLS_SITE = https://files.pythonhosted.org/packages/43/e5/d471fcb0e14523fe1c3f4ba58ca52480e7bd70ad7109a3846bc75892f7fb
PYTHON_HTTPTOOLS_SETUP_TYPE = setuptools
PYTHON_HTTPTOOLS_LICENSE = MIT
PYTHON_HTTPTOOLS_LICENSE_FILES = LICENSE

$(eval $(python-package))
