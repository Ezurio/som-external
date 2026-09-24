################################################################################
#
# python-bincopy
#
################################################################################

PYTHON_BINCOPY_VERSION = 20.1.0
PYTHON_BINCOPY_SOURCE = bincopy-$(PYTHON_BINCOPY_VERSION).tar.gz
PYTHON_BINCOPY_SITE = https://files.pythonhosted.org/packages/dc/81/6cbb95b67abccf8b1519d393931f6e6478f5eb63126ef18290959108d385
PYTHON_BINCOPY_SETUP_TYPE = setuptools
PYTHON_BINCOPY_LICENSE = MIT
PYTHON_BINCOPY_LICENSE_FILES = LICENSE
HOST_PYTHON_BINCOPY_DEPENDENCIES = \
	host-python-argparse-addons \
	host-python-humanfriendly \
	host-python-pyelftools

$(eval $(python-package))
$(eval $(host-python-package))
