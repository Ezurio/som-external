################################################################################
#
# python-argparse-addons
#
################################################################################

PYTHON_ARGPARSE_ADDONS_VERSION = 0.12.0
PYTHON_ARGPARSE_ADDONS_SOURCE = argparse_addons-$(PYTHON_ARGPARSE_ADDONS_VERSION).tar.gz
PYTHON_ARGPARSE_ADDONS_SITE = https://files.pythonhosted.org/packages/9e/35/33ecca1cdbebc5397a77f66edbc20ab76265176f7e3511b7696008ad9038
PYTHON_ARGPARSE_ADDONS_SETUP_TYPE = setuptools
PYTHON_ARGPARSE_ADDONS_LICENSE = MIT
PYTHON_ARGPARSE_ADDONS_LICENSE_FILES = LICENSE

$(eval $(python-package))
$(eval $(host-python-package))
