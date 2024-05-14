#####################################################################
#  Summit Serial Echo Test utility
#####################################################################

ECHOTEST_VERSION = local
ECHOTEST_SITE = $(ECHOTEST_PKGDIR)/source
ECHOTEST_SITE_METHOD = local
ECHOTEST_SETUP_TYPE = setuptools

$(eval $(python-package))
