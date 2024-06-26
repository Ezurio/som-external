################################################################################
#
# python-transitions
#
################################################################################

PYTHON_TRANSITIONS_VERSION = 0.9.1
PYTHON_TRANSITIONS_SOURCE = transitions-$(PYTHON_TRANSITIONS_VERSION).tar.gz
PYTHON_TRANSITIONS_SITE = https://files.pythonhosted.org/packages/25/eb/b35901548315a66dd9e84c9dbb0e19532090051a78797586e8c2a56bf376
PYTHON_TRANSITIONS_SETUP_TYPE = setuptools
PYTHON_TRANSITIONS_LICENSE = MIT
PYTHON_TRANSITIONS_LICENSE_FILES = LICENSE

$(eval $(python-package))
