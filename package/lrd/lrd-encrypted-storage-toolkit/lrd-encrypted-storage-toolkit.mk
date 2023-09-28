#############################################################
#
# lrd-encrypted-storage-toolkit
#
#############################################################

ifeq ($(BR2_PACKAGE_LRD_ENCRYPTED_STORAGE_TOOLKIT_EXEC_PERM),y)
define LRD_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_EXEC_PERM
	$(INSTALL) -d $(TARGET_DIR)/etc/default
	echo "PERM_MOUNT_OPTS=\"noatime,nosuid\"" > $(TARGET_DIR)/etc/default/perm-mount-opts
endef
endif

define LRD_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_TARGET_CMDS
	rsync -rlpDWK --no-perms --exclude=.empty  $(LRD_ENCRYPTED_STORAGE_TOOLKIT_PKGDIR)/rootfs/ $(TARGET_DIR)/
	$(LRD_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_EXEC_PERM)
endef

# setup files for factory reset and /data usage
BACKUP_SECRET_DIR = $(TARGET_DIR)/usr/share/factory/etc/secret
BACKUP_MISC_DIR = $(TARGET_DIR)/usr/share/factory/etc/misc

define LRD_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK
	set -x

	ln -sf /perm/etc/machine-id $(TARGET_DIR)/etc/machine-id

	mkdir -p $(BACKUP_SECRET_DIR)

	if [ -x $(TARGET_DIR)/usr/sbin/dropbear ]; then \
		unlink $(TARGET_DIR)/etc/dropbear; \
		ln -sf /data/secret/dropbear $(TARGET_DIR)/etc/dropbear; \
		mkdir -p $(BACKUP_SECRET_DIR)/dropbear; \
	fi

	# Factory data is only used with LCM/RCM
	if [ -x $(TARGET_DIR)/usr/bin/weblcm-python ] || [ -x $(TARGET_DIR)/usr/bin/summit-rcm ]; then \
		for BACKUP_TARGET in "weblcm-python" "modem" "stunnel" "chrony" "summit-rcm"; do
			if [ -d $(TARGET_DIR)/etc/"$${BACKUP_TARGET}" ];then \
				mv $(TARGET_DIR)/etc/$${BACKUP_TARGET}/ $(BACKUP_SECRET_DIR); \
				ln -sf /data/secret/$${BACKUP_TARGET} $(TARGET_DIR)/etc/$${BACKUP_TARGET}; \
			fi; \
		done
	fi

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
