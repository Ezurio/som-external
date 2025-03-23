################################################################################
#
# python-transitions
#
################################################################################

PYTHON_TRANSITIONS_VERSION = 0.9.2
PYTHON_TRANSITIONS_SOURCE = transitions-$(PYTHON_TRANSITIONS_VERSION).tar.gz
PYTHON_TRANSITIONS_SITE = https://files.pythonhosted.org/packages/4a/82/4dfbb3cf62501cb3e8d026cbeb2d5cdeaf5bfe916ea50d3a9435faa2b0e1
PYTHON_TRANSITIONS_SETUP_TYPE = setuptools
PYTHON_TRANSITIONS_LICENSE = MIT
PYTHON_TRANSITIONS_LICENSE_FILES = LICENSE

$(eval $(python-package))
