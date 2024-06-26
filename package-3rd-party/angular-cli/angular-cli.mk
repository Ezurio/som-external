################################################################################
#
# host-angular-cli
#
################################################################################

HOST_ANGULAR_CLI_VERSION = v1.0.0-beta.25
HOST_ANGULAR_CLI_SITE = $(call github,angular,angular-cli,$(HOST_ANGULAR_CLI_VERSION))
HOST_ANGULAR_CLI_LICENSE = MIT
HOST_ANGULAR_CLI_LICENSE_FILES = LICENSE

HOST_ANGULAR_CLI_DEPENDENCIES = host-nodejs

define HOST_ANGULAR_CLI_INSTALL_CMDS
	cd $(@D); PATH=$(BR_PATH) $(HOST_DIR)/bin/npm install -g $(@D)
endef

# Angluar-cli uses npm to install
$(eval $(host-generic-package))
