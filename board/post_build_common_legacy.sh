#!/bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

BUILD_TYPE="${1}"

[ -z "${BR2_SUMMIT_PRODUCT}" ] && \
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD COMMON LEGACY script: starting..."

# enable tracing and exit on errors
set -x -e

# remove default ssh init file
# real version is in init.d/opt and works w/ inetd or standalone
rm -f "${TARGET_DIR}/etc/init.d/S50sshd"

# remove default init scripts, they are replaced
rm -f "${TARGET_DIR}/etc/init.d/S50lighttpd"
rm -f "${TARGET_DIR}/etc/init.d/S20urandom"
rm -f "${TARGET_DIR}/etc/init.d/S40network"
rm -f "${TARGET_DIR}/etc/init.d/S41dhcpcd"
rm -f "${TARGET_DIR}/etc/init.d/S40bluetoothd"
rm -f "${TARGET_DIR}/etc/init.d/S35iptables"
rm -f "${TARGET_DIR}/etc/init.d/S50crond"
rm -f "${TARGET_DIR}/etc/init.d/S41ifplugd"

# remove perl cruft
rm -f "${TARGET_DIR}/etc/ssl/misc/tsget"
rm -f "${TARGET_DIR}/etc/ssl/misc/CA.pl"
rm -f "${TARGET_DIR}/usr/bin/pcf2vpnc"
rm -f "${TARGET_DIR}/usr/bin/chkdupexe"

# remove debian cruft
rm -fr "${TARGET_DIR}/etc/network/if-"*

# Copy the rootfs-additions-common in place first.
# If necessary, these can be overwritten by the product specific rootfs-additions.
rsync -rlptDWK --no-perms --exclude=.empty "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/rootfs-additions-common/" "${TARGET_DIR}"

# Copy the board specific rootfs additions
case "${BUILD_TYPE}" in
	"wb50n" | "wb45n")
		rsync -rlptDWK --no-perms --exclude=.empty "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/${BUILD_TYPE}/rootfs-additions/" "${TARGET_DIR}"
		;;
esac

# install libnl*.so.3 links
ln -rsf "${TARGET_DIR}/usr/lib/libnl-3.so" "${TARGET_DIR}/usr/lib/libnl.so.3"
ln -rsf "${TARGET_DIR}/usr/lib/libnl-genl-3.so" "${TARGET_DIR}/usr/lib/libnl-genl.so.3"

# create missing symbolic link
# TODO: shouldn't have to do this here, temporary workaround
ln -rsf "${TARGET_DIR}/usr/lib/libsdc_sdk.so.1.0" "${TARGET_DIR}/usr/lib/libsdc_sdk.so.1"

# wireless.sh won't be able to create this with the ro file system
ln -rsf "${TARGET_DIR}/etc/network/wireless.sh" "${TARGET_DIR}/sbin/wireless"

# Services to disable by default
[ -f "${TARGET_DIR}/etc/init.d/S??lighttpd" ] && \
	chmod a-x "${TARGET_DIR}/etc/init.d/S??lighttpd"

# Remove the custom bluetooth init-script if bluez utility is not included
if [ -x "${TARGET_DIR}/usr/bin/hciconfig" ]; then
	# background the bluetooth init-script
	mv "${TARGET_DIR}/etc/init.d/S95bluetooth" "${TARGET_DIR}/etc/init.d/S95bluetooth.bg"

	# Customize BlueZ Bluetooth advertised name
	if [ -e "${TARGET_DIR}/etc/bluetooth/main.conf" ]; then
		sed -i "s/.*Name *=.*/Name = Summit-${BR2_SUMMIT_PRODUCT^^}/" "${TARGET_DIR}/etc/bluetooth/main.conf"
	fi
else
	rm -f "${TARGET_DIR}/etc/init.d/S95bluetooth"*
	rm -f "${TARGET_DIR}/usr/bin/bttest.sh"
fi

if [ ! -x "${TARGET_DIR}/usr/sbin/hostapd" ]; then
	rm -rf "${TARGET_DIR}/etc/hostapd"
	rm -rf "${TARGET_DIR}/bin/hostapd_mode"
fi

if [ ! -x "${TARGET_DIR}/usr/sbin/lighttpd" ]; then
	rm -f "${TARGET_DIR}/sbin/lighty"*
	rm -f "${TARGET_DIR}/etc/init.d/opt/S50lighty"
	rm -f "${TARGET_DIR}/etc/init.d/S99lighttpd"
	sed -i 's/^http/#http/' "${TARGET_DIR}/etc/inetd.conf"
else
	# install weblcm certs
	mkdir -p "${TARGET_DIR}/etc/weblcm/certs"
	cp -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.pem" "${TARGET_DIR}/etc/weblcm/certs/server.pem"
fi

if [ ! -x "${TARGET_DIR}/usr/sbin/proftpd" ]; then
	sed -i 's/^ftp/#ftp/' "${TARGET_DIR}/etc/inetd.conf"
fi

if [ ! -x "${TARGET_DIR}/usr/sbin/pppd" ]; then
	rm -f "${TARGET_DIR}/etc/init.d/opt/S45pppd"
fi

if [ ! -x "${TARGET_DIR}/usr/sbin/sshd" ]; then
	rm -f "${TARGET_DIR}/etc/init.d/opt/S50sshd"
	sed -i 's/^ssh/#ssh/' "${TARGET_DIR}/etc/inetd.conf"
fi

[ -n "$(find "${TARGET_DIR}/lib/modules/" -name ohci-at91.ko)" ] || \
	rm -f "${TARGET_DIR}/etc/init.d/S37usbhost"

[ -n "$(find "${TARGET_DIR}/lib/modules/" -name cryptodev.ko)" ] || \
	rm -f "${TARGET_DIR}/etc/init.d/S03cryptodev"

if [ -x "${TARGET_DIR}/usr/bin/dcas" ]; then

# adjust ssh_config and sshd_config to stop using root and use /etc/ instead.
sed -i "s/AuthorizedKeysFile.*/AuthorizedKeysFile\t\/etc\/.ssh\/authorized_keys/" "${TARGET_DIR}/etc/ssh/sshd_config"
cat << EOF >> "${TARGET_DIR}/etc/ssh/ssh_config"
IdentityFile /etc/.ssh/identity" >> 
IdentityFile /etc/.ssh/id_rsa
UserKnownHostsFile /etc/.ssh/known_hosts
EOF

# add SSH directories in /etc/
mkdir -p "${TARGET_DIR}/etc/.ssh"
touch "${TARGET_DIR}/etc/.ssh/authorized_keys"

# make sure SSH permissions are correct
chmod 700 "${TARGET_DIR}/etc/.ssh"
chmod 600 "${TARGET_DIR}/etc/.ssh/authorized_keys"

# adjust DCAS SSH location
sed -i "s/dcas_auth_dir.*/dcas_auth_dir=\/etc\/.ssh/" "${TARGET_DIR}/etc/dcas.conf"
sed -i "s/DEFAULT_AUTH_DIR=.*/DEFAULT_AUTH_DIR=\/etc\/.ssh/" "${TARGET_DIR}/etc/init.d/S99dcas"

fi

# Fixup and add debugfs to fstab
sed -i 's|/dev/root.*|/dev/root	/		auto	rw,noauto,noatime	0	1|' "${TARGET_DIR}/etc/fstab"
grep -qF "/sys/kernel/debug" "${TARGET_DIR}/etc/fstab" ||\
	echo 'nodev		/sys/kernel/debug debugfs defaults	0	0' >> "${TARGET_DIR}/etc/fstab"

# create a compressed backup copy of the /e/n/i file
gzip -c "${TARGET_DIR}/etc/network/interfaces" > "${TARGET_DIR}/etc/network/interfaces~.gz"

# Create default firmware description file.
# This may be overwritten by a proper release file.
LOCRELSTR="${SUMMIT_RELEASE_STRING}"
if [ -z "${LOCRELSTR}" ] || [ "${LOCRELSTR}" = "0.0.0.0" ]; then
	LOCRELSTR="Summit Linux development build 0.${BR2_SUMMIT_BRANCH}.0.0"
	DATE_SUFFIX="-$(date +%Y%m%d)"
else
	DATE_SUFFIX=""
fi
echo "${LOCRELSTR}" > "${TARGET_DIR}/etc/issue"

cat << EOF > "${TARGET_DIR}/usr/lib/os-release"
NAME="Summit Linux"
VERSION="${LOCRELSTR}"
ID=${BR2_SUMMIT_PRODUCT}
VERSION_ID=${BR2_SUMMIT_BUILD_VERSION}${DATE_SUFFIX}
BUILD_ID=${BR2_SUMMIT_PRODUCT}-${BR2_SUMMIT_BUILD_VERSION}${DATE_SUFFIX}
PRETTY_NAME="${LOCRELSTR}"
EOF

if grep -qF "BR2_LINUX_KERNEL_IMAGE_TARGET_CUSTOM=y" "${BR2_CONFIG}"; then
	case "${BUILD_TYPE}" in
		"wb50n") 
			export KERNEL_IMAGE="Image.gz"
			export linux_comp="gzip"
			;;
		"wb45n") 
			export KERNEL_IMAGE="Image.lzma"
			export linux_comp="lzma"
			;;
		*)
			exit 1
			;;
	esac

	export UBOOT_LOADADDRESS=0x20008000
	export UBOOT_ENTRYPOINT=0x20008000
	export FDT_LOADADDRESS=
	export UBOOT_ARCH="arm"

	mapfile -t < <(make --no-print-directory -C "${BASE_DIR}" linux-show-version \
		uboot-show-version linux-show-dtb | sed '/^make\[/d')
	read -r LINUX_VER UBOOT_VER KERNEL_DEVICETREE <<< "${MAPFILE[@]}"
	export LINUX_VER UBOOT_VER KERNEL_DEVICETREE

	kver=$(make --no-print-directory -C "${BUILD_DIR}/linux-${LINUX_VER}" kernelrelease \
		| sed '/^make\[/d')
	export FIT_SUMMIT_VERSION=Linux-${kver}-${BR2_SUMMIT_BUILD_VERSION}

	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/kernel-fitimage.sh" "${BINARIES_DIR}/kernel.its"
fi

case $(sed -rn 's/BR2_SUMMIT_FIPS_([0-9]+)=y/\1/p' "${BR2_CONFIG}") in
	7)
		install -D -m 0644 -t "${TARGET_DIR}/usr/lib/fipscheck" \
			"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/fips_hash/7.1/${BUILD_TYPE}/"*
		;;
	11)
		install -D -m 0644 -t "${TARGET_DIR}/usr/lib/fipscheck" \
			"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/fips_hash/11.0/${BUILD_TYPE}/"*
		;;
esac

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD COMMON LEGACY script: done."
