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
	if [ -d $(TARGET_DIR)/etc/dropbear ]; then \
		unlink $(TARGET_DIR)/etc/dropbear; \
		mkdir -p $(TARGET_DIR)/etc/dropbear; \
	fi;

	mkdir -p $(BACKUP_SECRET_DIR)
	for BACKUP_TARGET in "firewalld" "weblcm-python" "modem" "stunnel" "chrony" "dropbear" "summit-rcm"; do \
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

	if [ -f $(TARGET_DIR)/etc/NetworkManager/NetworkManager.state ];then \
		mv $(TARGET_DIR)/etc/NetworkManager/NetworkManager.state $(BACKUP_SECRET_DIR)
	fi

	ln -sf /data/secret/NetworkManager.state $(TARGET_DIR)/etc/NetworkManager/NetworkManager.state

	mkdir -p $(BACKUP_MISC_DIR)
	mv $(TARGET_DIR)/etc/timezone $(BACKUP_MISC_DIR)

	ln -sf /data/misc/timezone $(TARGET_DIR)/etc/timezone
	ln -sf /data/misc/localtime $(TARGET_DIR)/etc/localtime
	ln -sf /data/misc/adjtime $(TARGET_DIR)/etc/adjtime

	if [ -d $(BACKUP_SECRET_DIR)/weblcm-python/ssl ]; then \
		rm -rf $(BACKUP_SECRET_DIR)/weblcm-python/ssl; \
		ln -sf /rodata/secret/rest-server/ssl $(BACKUP_SECRET_DIR)/weblcm-python/ssl; \
	fi;

	if [ -d $(BACKUP_SECRET_DIR)/summit-rcm/ssl ]; then \
		rm -rf $(BACKUP_SECRET_DIR)/summit-rcm/ssl; \
		ln -sf /rodata/secret/rest-server/ssl $(BACKUP_SECRET_DIR)/summit-rcm/ssl; \
	fi;
endef

LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOKS += LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK

$(eval $(generic-package))
