################################################################################
#
# host-python-spsdk
#
# NXP Secure Provisioning SDK – provides the nxpimage tool used for
# AHAB container signing on i.MX9x platforms.
#
################################################################################

PYTHON_SPSDK_VERSION = 3.7.0
PYTHON_SPSDK_SOURCE = spsdk-$(PYTHON_SPSDK_VERSION).tar.gz
PYTHON_SPSDK_SITE = https://files.pythonhosted.org/packages/source/s/spsdk
PYTHON_SPSDK_SETUP_TYPE = setuptools
PYTHON_SPSDK_LICENSE = BSD-3-Clause
PYTHON_SPSDK_LICENSE_FILES = LICENSE

HOST_PYTHON_SPSDK_DEPENDENCIES = \
	host-python-click \
	host-python-crcmod \
	host-python-cryptography \
	host-python-deepmerge \
	host-python-fastjsonschema \
	host-python-filelock \
	host-python-pyyaml \
	host-python-requests \
	host-python-ruamel-yaml \
	host-python-serial \
	host-python-setuptools-scm \
	host-python-typing-extensions

$(eval $(host-python-package))
