#############################################################
#
# summit-encrypted-storage-toolkit
#
#############################################################

ifeq ($(BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_EXEC_PERM),y)
define SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_EXEC_PERM
	$(INSTALL) -d $(TARGET_DIR)/etc/default
	echo "PERM_MOUNT_OPTS=\"noatime,nosuid\"" > $(TARGET_DIR)/etc/default/perm-mount-opts
endef
endif

ifeq ($(BR2_aarch64),y)
define SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_INHERIT
	$(SED) '/KeyringMode/d;/\[Service\]/d' \
		$(TARGET_DIR)/usr/lib/systemd/system/inherit-keyring.conf
	$(SED) '/KeyringMode/d' \
		$(TARGET_DIR)/usr/lib/systemd/system/mount_data.service
endef
endif

define SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_TARGET_CMDS
	rsync -rlpDWK --no-perms --inplace --exclude=.empty  $(SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_PKGDIR)/rootfs/ $(TARGET_DIR)/
	$(SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_EXEC_PERM)
	$(SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_INSTALL_INHERIT)
endef

# setup files for factory reset and /data usage
BACKUP_SECRET_DIR = $(TARGET_DIR)/usr/share/factory/etc/secret
BACKUP_MISC_DIR = $(TARGET_DIR)/usr/share/factory/etc/misc

define SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK
	set -x

	rm -rf $(TARGET_DIR)/media
	ln -sf /run/media $(TARGET_DIR)/media

	mkdir -p $(BACKUP_SECRET_DIR)

	if [ -x $(TARGET_DIR)/usr/sbin/dropbear ]; then \
		mv $(TARGET_DIR)/etc/dropbear $(BACKUP_SECRET_DIR)/dropbear; \
		ln -sf /data/secret/dropbear $(TARGET_DIR)/etc/dropbear; \
	fi

	# Factory data is only used with LCM/RCM
	if [ -x $(TARGET_DIR)/usr/bin/summit-rcm ]; then \
		for BACKUP_TARGET in "modem" "stunnel" "chrony" "summit-rcm"; do
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

	if ! grep -qF noexec $(TARGET_DIR)/usr/lib/systemd/system/var.mount; then \
		$(SED) '/^Options=/ s/$$/,noexec/' $(TARGET_DIR)/usr/lib/systemd/system/var.mount; \
	fi

	if ! grep -qF noexec $(TARGET_DIR)/usr/lib/systemd/system/tmp.mount; then \
		$(SED) '/^Options=/ s/$$/,noexec/' $(TARGET_DIR)/usr/lib/systemd/system/tmp.mount; \
	fi
endef

SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOKS += SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOK

ifneq ($(BR2_PACKAGE_SUMMIT_PROV),y)
define SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_SUMMIT_RCM_RODATA_ROOTFS_PRE_CMD_HOOK
	set -x

	if [ -d $(BACKUP_SECRET_DIR)/summit-rcm/ssl ]; then \
		rm -rf $(BACKUP_SECRET_DIR)/summit-rcm/ssl; \
		ln -sf /rodata/secret/rest-server/ssl $(BACKUP_SECRET_DIR)/summit-rcm/ssl; \
	fi
endef
SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_ROOTFS_PRE_CMD_HOOKS += SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_SUMMIT_RCM_RODATA_ROOTFS_PRE_CMD_HOOK
endif

$(eval $(generic-package))
