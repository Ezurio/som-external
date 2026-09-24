################################################################################
#
# python-t61codec
#
################################################################################

PYTHON_T61CODEC_VERSION = 2.0.0
PYTHON_T61CODEC_SOURCE = t61codec-$(PYTHON_T61CODEC_VERSION).tar.gz
PYTHON_T61CODEC_SITE = https://files.pythonhosted.org/packages/5c/a1/3dad66921f116dab998b9c983a6b78da1c692f5b61b2962a7c6348c0cc40
PYTHON_T61CODEC_SETUP_TYPE = poetry
PYTHON_T61CODEC_LICENSE = MIT
PYTHON_T61CODEC_LICENSE_FILES = LICENSE

$(eval $(host-python-package))
