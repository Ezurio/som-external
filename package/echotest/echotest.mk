#####################################################################
#  Summit Serial Echo Test utility
#####################################################################

ECHOTEST_VERSION = local
ECHOTEST_SITE = $(ECHOTEST_PKGDIR)/source
ECHOTEST_SITE_METHOD = local
ECHOTEST_LICENSE = Ezurio
ECHOTEST_LICENSE_FILES = LICENSE.ezurio
ECHOTEST_SETUP_TYPE = pep517
ECHOTEST_DEPENDENCIES = host-python-setuptools

$(eval $(python-package))
