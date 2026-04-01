################################################################################
#
# python-transitions
#
################################################################################

PYTHON_TRANSITIONS_VERSION = 0.9.3
PYTHON_TRANSITIONS_SOURCE = transitions-$(PYTHON_TRANSITIONS_VERSION).tar.gz
PYTHON_TRANSITIONS_SITE = https://files.pythonhosted.org/packages/4f/83/9e90f3494057d73c9e6bd8de8488af7c9fa714666ccc2db30fe07d147818
PYTHON_TRANSITIONS_SETUP_TYPE = setuptools
PYTHON_TRANSITIONS_LICENSE = MIT
PYTHON_TRANSITIONS_LICENSE_FILES = LICENSE

$(eval $(python-package))
