################################################################################
#
# python-hexdump
#
################################################################################

PYTHON_HEXDUMP_VERSION = 3.3
PYTHON_HEXDUMP_SOURCE = hexdump-$(PYTHON_HEXDUMP_VERSION).zip
PYTHON_HEXDUMP_SITE = https://files.pythonhosted.org/packages/55/b3/279b1d57fa3681725d0db8820405cdcb4e62a9239c205e4ceac4391c78e4
PYTHON_HEXDUMP_SITE_METHOD = wget
PYTHON_HEXDUMP_SETUP_TYPE = setuptools
PYTHON_HEXDUMP_LICENSE = Public Domain

define HOST_PYTHON_HEXDUMP_EXTRACT_CMDS
	$(UNZIP) $(HOST_PYTHON_HEXDUMP_DL_DIR)/$(HOST_PYTHON_HEXDUMP_SOURCE) -d $(@D)
endef

define PYTHON_HEXDUMP_EXTRACT_CMDS
	$(UNZIP) $(PYTHON_HEXDUMP_DL_DIR)/$(PYTHON_HEXDUMP_SOURCE) -d $(@D)
endef

$(eval $(python-package))
$(eval $(host-python-package))
