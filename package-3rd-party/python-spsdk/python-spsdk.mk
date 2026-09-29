################################################################################
#
# host-python-spsdk
#
# NXP Secure Provisioning SDK – provides nxpimage and the HAB4 binman
# adapter used for i.MX8M signing, as well as AHAB container signing.
#
################################################################################

PYTHON_SPSDK_VERSION = 3.11.0
PYTHON_SPSDK_SOURCE = spsdk-$(PYTHON_SPSDK_VERSION).tar.gz
PYTHON_SPSDK_SITE = https://files.pythonhosted.org/packages/source/s/spsdk
PYTHON_SPSDK_SETUP_TYPE = setuptools
PYTHON_SPSDK_LICENSE = BSD-3-Clause
PYTHON_SPSDK_LICENSE_FILES = LICENSE

PYTHON_SPSDK_DEPENDENCIES = \
	python-bincopy \
	python-bitstring \
	python-chardet \
	python-colorama \
	python-click-command-tree \
	python-click-option-group \
	python-hexdump \
	python-platformdirs \
	python-pyasn1 \
	python-click \
	python-humanfriendly \
	python-importlib-metadata \
	python-jinja2 \
	python-oscrypto \
	python-prettytable \
	python-serial \
	python-sly \
	python-t61codec \
	python-x690 \
	python-crcmod \
	python-cryptography \
	python-deepmerge \
	python-fastjsonschema \
	python-filelock \
	python-pyyaml \
	python-requests \
	python-ruamel-yaml \
	python-typing-extensions \
	python-asn1crypto \
	python-packaging \
	host-python-setuptools-scm

HOST_PYTHON_SPSDK_DEPENDENCIES = \
	host-python-bincopy \
	host-python-bitstring \
	host-python-chardet \
	host-python-colorama \
	host-python-click-command-tree \
	host-python-click-option-group \
	host-python-hexdump \
	host-python-platformdirs \
	host-python-pyasn1 \
	host-python-click \
	host-python-humanfriendly \
	host-python-importlib-metadata \
	host-python-jinja2 \
	host-python-oscrypto \
	host-python-prettytable \
	host-python-serial \
	host-python-sly \
	host-python-t61codec \
	host-python-x690 \
	host-python-crcmod \
	host-python-cryptography \
	host-python-deepmerge \
	host-python-fastjsonschema \
	host-python-filelock \
	host-python-pyyaml \
	host-python-requests \
	host-python-ruamel-yaml \
	host-python-setuptools-scm \
	host-python-typing-extensions \
	host-python-asn1crypto \
	host-python-packaging

define HOST_PYTHON_SPSDK_INSTALL_HAB4_WRAPPER
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_SUMMIT_SOM_PATH)/package-3rd-party/python-spsdk/spsdk-hab4-sign.py $(HOST_DIR)/bin/spsdk-hab4-sign.py
endef

HOST_PYTHON_SPSDK_POST_INSTALL_HOOKS += HOST_PYTHON_SPSDK_INSTALL_HAB4_WRAPPER

$(eval $(python-package))
$(eval $(host-python-package))
