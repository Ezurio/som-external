#############################################################
#
# lrd-encrypted-storage-toolkit
#
#############################################################

define LRD_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_TARGET_CMDS
	rsync -rlpDWK --no-perms --exclude=.empty  $(LRD_ENCRYPTED_STORAGE_TOOLKIT_PKGDIR)/rootfs/ $(TARGET_DIR)/
endef

# setup files for factory reset and /data usage
BACKUP_SECRET_DIR = $(TARGET_DIR)/usr/share/factory/etc/secret
BACKUP_MISC_DIR = $(TARGET_DIR)/usr/share/factory/etc/misc

define LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK
	unlink $(TARGET_DIR)/etc/dropbear; \
	mkdir -p $(TARGET_DIR)/etc/dropbear; \

	mkdir -p $(BACKUP_SECRET_DIR)
	for BACKUP_TARGET in "firewalld" "weblcm-python" "modem" "stunnel" "chrony" "dropbear"; do \
		if [ -d $(TARGET_DIR)/etc/"$${BACKUP_TARGET}" ];then \
			mv $(TARGET_DIR)/etc/$${BACKUP_TARGET}/ $(BACKUP_SECRET_DIR); \
			ln -sf /data/secret/$${BACKUP_TARGET} $(TARGET_DIR)/etc/$${BACKUP_TARGET}; \
		fi; \
	done

	set -x

	mkdir -p $(BACKUP_SECRET_DIR)/NetworkManager
	for SM_SUB_DIR in "certs" "system-connections"; do \
		if [ -d $(TARGET_DIR)/etc/NetworkManager/$${SM_SUB_DIR} ]; then \
			mv $(TARGET_DIR)/etc/NetworkManager/$${SM_SUB_DIR} $(BACKUP_SECRET_DIR)/NetworkManager; \
		else \
			mkdir -p $(BACKUP_SECRET_DIR)/NetworkManager/$${SM_SUB_DIR}; \
		fi; \
		ln -sf /data/secret/NetworkManager/$${SM_SUB_DIR} $(TARGET_DIR)/etc/NetworkManager/$${SM_SUB_DIR}; \
	done

	ln -sf /data/secret/NetworkManager.state $(TARGET_DIR)/etc/NetworkManager/NetworkManager.state

	mkdir -p $(BACKUP_MISC_DIR)
	mv $(TARGET_DIR)/etc/timezone $(BACKUP_MISC_DIR)

	ln -sf /data/misc/timezone $(TARGET_DIR)/etc/timezone
	ln -sf /data/misc/localtime $(TARGET_DIR)/etc/localtime
	ln -sf /data/misc/adjtime $(TARGET_DIR)/etc/adjtime
endef

LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOKS += LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK

$(eval $(generic-package))
