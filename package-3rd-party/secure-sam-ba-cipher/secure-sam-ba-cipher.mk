################################################################################
#
# secure-sam-ba-cipher
#
################################################################################

SECURE_SAM_BA_CIPHER_VERSION = 3.5
SECURE_SAM_BA_CIPHER_SITE_METHOD = git
SECURE_SAM_BA_CIPHER_SITE = git@github.com:rfpros/secure-sam-ba-cipher.git
SECURE_SAM_BA_CIPHER_LICENSE = GPL-2.0
SECURE_SAM_BA_CIPHER_LICENSE_FILES = LICENSE

define HOST_SECURE_SAM_BA_CIPHER_INSTALL_CMDS
	mkdir -p $(HOST_DIR)/opt/secure-sam-ba-cipher/
	cp -a $(@D)/* $(HOST_DIR)/opt/secure-sam-ba-cipher/
endef

$(eval $(host-generic-package))
