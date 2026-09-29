################################################################################
#
# python-sly
#
################################################################################

PYTHON_SLY_VERSION = 0.5
PYTHON_SLY_SOURCE = sly-$(PYTHON_SLY_VERSION).tar.gz
PYTHON_SLY_SITE = https://files.pythonhosted.org/packages/41/8a/59e943f7b27904c7756a7b565ffbd55f3841f5cd3d2da2b2b0713c49e488
PYTHON_SLY_SITE_METHOD = wget
PYTHON_SLY_SETUP_TYPE = setuptools
PYTHON_SLY_LICENSE = BSD-3-Clause
PYTHON_SLY_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
