################################################################################
#
# host-angular-cli
#
################################################################################

HOST_ANGULAR_CLI_VERSION = v1.0.0-beta.25
HOST_ANGULAR_CLI_SITE = https://github.com/angular/angular-cli.git
HOST_ANGULAR_CLI_SITE_METHOD = git
HOST_ANGULAR_CLI_DEPENDENCIES = host-nodejs

define HOST_ANGULAR_CLI_INSTALL_CMDS
	cd $(@D); \
		PATH=$(BR_PATH) \
		$(HOST_DIR)/bin/npm install -g $(@D)
endef

# Angluar-cli uses npm to install
$(eval $(host-generic-package))
