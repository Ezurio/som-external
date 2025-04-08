#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

# enable tracing and exit on errors
set -x -e -o pipefail

BOARD_DIR="${1}"
export BUILD_TYPE="${2}"

if [ -n "${KEYS_DIR}" ]; then
	# Keys directory is set, use custom keys for secure provisioning
	[ -d "${KEYS_DIR}" ] || \
		{ echo "Keys directory not found: ${KEYS_DIR}"; exit 1; }
else
	KEYS_DIR="${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys"
fi

[ -n "${BR2_SUMMIT_PRODUCT}" ] || \
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD COMMON script: starting..."

case "${BUILD_TYPE}" in
*sd) SD=true  ;;
  *) SD=false ;;
esac

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT=y" "${BR2_CONFIG}" \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false
export ENCRYPTED_TOOLKIT

grep -qF "BR2_SUMMIT_SECURE_BOOT=y" "${BR2_CONFIG}" \
	&& SECURE_BOOT=true || SECURE_BOOT=false
export SECURE_BOOT

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
PACKAGE_ID=${BR2_SUMMIT_PRODUCT}${BR2_SUMMIT_BUILD_SUFFIX}-summit-${BR2_SUMMIT_BUILD_VERSION}
PRETTY_NAME="${LOCRELSTR}"
EOF

# Copy the product specific rootfs additions, strip host user access control
rsync -aWKE --no-perms --exclude=.empty "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/rootfs-additions-60/" "${TARGET_DIR}"
if [ -d "${BOARD_DIR}/rootfs-additions/" ]; then
	rsync -aWKE --no-perms --exclude=.empty "${BOARD_DIR}/rootfs-additions/" "${TARGET_DIR}"
fi

# Split out OpenJDK dependencies to a separate tarball to support
# running AWS IoT Greengrass V2
if grep -qF BR2_SUMMIT_OPENJDK_GGV2=y "${BR2_CONFIG}"; then
	# Create temporary directory and move 'modules' file to it
	rm -rf "${BINARIES_DIR}/jdk/lib/"
	mkdir -p "${BINARIES_DIR}/jdk/lib"
	mv "${TARGET_DIR}/usr/lib/jvm/lib/modules" "${BINARIES_DIR}/jdk/lib/"

	# Create tarball
	tar -C "${BINARIES_DIR}" -czvf "${BINARIES_DIR}/openjdk.tar.gz" jdk

	# Create symlink the place of the 'modules' file
	ln -sf /run/media/mmcblk0p1/jdk/lib/modules "${TARGET_DIR}/usr/lib/jvm/lib/modules"

	# Remove other unneeded files
	rm -f "${TARGET_DIR}/usr/lib/jvm/lib/src.zip"
	rm -rf "${TARGET_DIR}/usr/lib/jvm/lib/jmods/"
	rm -f "${TARGET_DIR}/usr/lib/jvm/lib/ct.sym"
	rm -rf "${TARGET_DIR}/usr/share/cups"
fi

if grep -qF BR2_PACKAGE_SUMMIT_RCM_CERTIFICATE_PROVISIONING_PLUGIN=y "${BR2_CONFIG}" && ${ENCRYPTED_TOOLKIT} ; then
    ln -sf /data/secret/fallback_timestamp "${TARGET_DIR}/etc/fallback_timestamp"

    mkdir -p "${TARGET_DIR}/usr/share/factory/etc/secret/permanent/provisioning"
    ln -sf /data/secret/permanent/provisioning "${TARGET_DIR}/etc/summit-rcm/provisioning"

	# Preserve factory-provisioned files
	# shellcheck disable=SC2016
	sed -i 's/rm -fr ${USER_SETTINGS_SECRET_TARGET}\/\*/find ${USER_SETTINGS_SECRET_TARGET} -maxdepth 1 -mindepth 1 ! -name permanent -exec rm -fr {} \\;/g' "${TARGET_DIR}/usr/sbin/do_factory_reset.sh"
fi

[ -f "${BINARIES_DIR}/u-boot-initial-env" ] && \
	cp -ft "${TARGET_DIR}/etc" "${BINARIES_DIR}/u-boot-initial-env"

if ! grep -qF BR2_TARGET_GENERIC_REMOUNT_ROOTFS_RW=y "${BR2_CONFIG}" ; then
	sed -i -r '\,/dev/root, s,rw,ro,' "${TARGET_DIR}/etc/fstab"
fi

if ! grep -qF BR2_INIT_SYSTEMD=y "${BR2_CONFIG}" && \
	! grep -qF /sys/kernel/debug "${TARGET_DIR}/etc/fstab" ; 
then
	echo 'debugfs    /sys/kernel/debug      debugfs  defaults  0 0' >> "${TARGET_DIR}/etc/fstab"
fi

# No need to detect SmartMedia cards, thus remove errors and speedup boot
rm -f "${TARGET_DIR}/usr/lib/udev/rules.d/75-probe_mtd.rules"

# Fixup systemd default to avoid errors
if [ -f "${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf" ]; then
	sed -i 's/^net\.core\.default_qdisc/# net\.core\.default_qdisc/' "${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf"
	sed -i 's/^kernel\.sysrq/# kernel\.sysrq/' "${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf"
fi

if [ -x "${TARGET_DIR}/usr/sbin/NetworkManager" ]; then
	mkdir -p "${TARGET_DIR}/etc/NetworkManager/system-connections"

	# Make sure connection files have proper attributes
	for f in "${TARGET_DIR}/usr/lib/NetworkManager/system-connections/"* "${TARGET_DIR}/etc/NetworkManager/system-connections/"* ; do
		if [ -f "${f}" ] ; then
			chmod 600 "${f}"
		fi
	done

	# Make sure dispatcher files have proper attributes
	[ -d "${TARGET_DIR}/etc/NetworkManager/dispatcher.d" ] && \
		find "${TARGET_DIR}/etc/NetworkManager/dispatcher.d" -type f -exec chmod 700 {} \;

	if [ -x "${TARGET_DIR}/usr/sbin/firewalld" ]; then
		sed -i "s/firewall-backend=.*/firewall-backend=none/g" "${TARGET_DIR}/etc/NetworkManager/NetworkManager.conf"
	fi

	ln -sf /run/NetworkManager/resolv.conf "${TARGET_DIR}/etc/resolv.conf"
fi

# Remove not needed systemd generators
rm -f "${TARGET_DIR}/usr/lib/systemd/system/sysinit.target.wants/sys-fs-fuse-connections.mount"

if [ -f "${TARGET_DIR}/usr/lib/systemd/system/systemd-logind.service" ] && \
   ! grep -qF "BR2_PACKAGE_LIBDRM=y" "${BR2_CONFIG}"; then
	sed -i 's/modprobe@drm.service//g' \
		"${TARGET_DIR}/usr/lib/systemd/system/systemd-logind.service"
fi

# Remove bluetooth support when BlueZ 5 not present
if [ ! -x "${TARGET_DIR}/usr/bin/btattach" ]; then
	rm -rf "${TARGET_DIR}/etc/bluetooth"
	rm -f "${TARGET_DIR}/etc/udev/rules.d/80-btattach.rules"
	rm -f "${TARGET_DIR}/usr/lib/systemd/system/btattach.service"
	rm -f "${TARGET_DIR}/usr/bin/bt-service.sh"
	rm -f "${TARGET_DIR}/usr/bin/bttest.sh"
else
	# Customize BlueZ Bluetooth advertised name
	if [ -e "${TARGET_DIR}/etc/bluetooth/main.conf" ]; then
		sed -i "s/.*Name *=.*/Name = Summit-${BR2_SUMMIT_PRODUCT^^}/" \
			"${TARGET_DIR}/etc/bluetooth/main.conf"
	fi
	if [ -f "${TARGET_DIR}/usr/lib/systemd/system/bluetooth.service" ]; then
		sed -i 's/ConfigurationDirectoryMode=0555/ConfigurationDirectoryMode=0755/g' \
			"${TARGET_DIR}/usr/lib/systemd/system/bluetooth.service"
	fi
fi

# Remove autoloading cryptodev module when not present
[ -n "$(find "${TARGET_DIR}/lib/modules/" -name cryptodev.ko)" ] || \
	rm -f "${TARGET_DIR}/etc/modules-load.d/cryptodev.conf"

# Remove TSLIB support configs if TSLIB not present
if [ ! -e "${TARGET_DIR}/usr/lib/libts.so.0" ]; then
	rm -f "${TARGET_DIR}/etc/ts.conf"
	rm -f "${TARGET_DIR}/etc/pointercal"
	rm -f "${TARGET_DIR}/etc/profile.d/ts-setup.sh"
fi

# Clean up Python, Node cruft we don't need
PYTHON_VERSION_MAJOR=$(find "${TARGET_DIR}/usr/lib" -maxdepth 1 -name 'python3.*' -exec basename {} \;)

rm -f "${TARGET_DIR}/usr/lib/${PYTHON_VERSION_MAJOR}/ensurepip/_bundled/"*.whl
rm -f "${TARGET_DIR}/usr/lib/${PYTHON_VERSION_MAJOR}/distutils/command/"*.exe
rm -f "${TARGET_DIR}/usr/lib/${PYTHON_VERSION_MAJOR}/site-packages/setuptools/"*.exe
# Do not remove Python distribution metadata when pip is enabled
if ! grep -qF "BR2_PACKAGE_PYTHON_PIP=y" "${BR2_CONFIG}"; then
    rm -rf "${TARGET_DIR}/usr/lib/${PYTHON_VERSION_MAJOR}/site-packages/"*.egg-info
fi

[ -d "${TARGET_DIR}/usr/lib/node_modules" ] && \
	find "${TARGET_DIR}/usr/lib/node_modules" -name '*.md' -exec rm -f {} \;

if ! grep -qF "BR2_PACKAGE_GOBJECT_INTROSPECTION=y" "${BR2_CONFIG}"; then
	rm -rf "${TARGET_DIR}/usr/share/gobject-introspection-1.0/"
	rm -rf "${TARGET_DIR}/usr/lib/gobject-introspection/"
fi

rm -rf "${TARGET_DIR}/var/www/swupdate"
rm -f "${TARGET_DIR}/usr/lib/swupdate/conf.d/90-start-progress"

if ${SD} && ! ${ENCRYPTED_TOOLKIT}; then
	echo 'export TMPDIR=/opt/swupdate' > \
		"${TARGET_DIR}/etc/swupdate/conf.d/90-tmpdir.conf"
	mkdir -p "${TARGET_DIR}/opt/swupdate"
fi

if [ ! -x "${TARGET_DIR}/usr/lib/systemd/systemd" ]; then
	rm -rf "${TARGET_DIR}/usr/lib/systemd"
	rm -rf "${TARGET_DIR}/etc/systemd"
fi

mapfile -t < <(make --no-print-directory -C "${BASE_DIR}" linux-show-version \
	uboot-show-version swupdate-show-version linux-show-dtb | sed '/^make\[/d')
read -r LINUX_VER UBOOT_VER SWUPDATE_VER KERNEL_DEVICETREE <<< "${MAPFILE[@]}"

FIT_CONF_DEFAULT_DTB="$(sed -rn 's,^BR2_SUMMIT_LINUX_DEFAULT_DTB="(.*)"$,\1,p' "${BR2_CONFIG}")"
CUSTOM_DTB_FILTER="$(sed -rn 's,^BR2_SUMMIT_LINUX_CUSTOM_DTB_FILTER="(.*)"$,\1,p' "${BR2_CONFIG}")"
if [ -n "${CUSTOM_DTB_FILTER}" ]; then
	filtered_dtbs=
	for dtb in ${KERNEL_DEVICETREE}; do
		for filter in ${CUSTOM_DTB_FILTER}; do
			case "${dtb}" in
				${filter}) 
					filtered_dtbs="${filtered_dtbs} ${dtb}"
					;;
				"${FIT_CONF_DEFAULT_DTB}")
					filtered_dtbs="${filtered_dtbs} ${dtb}"
					;;
			esac
		done
	done
	KERNEL_DEVICETREE="${filtered_dtbs}"
fi

export LINUX_VER UBOOT_VER SWUPDATE_VER KERNEL_DEVICETREE FIT_CONF_DEFAULT_DTB

SWUPDATE_CONF=${BUILD_DIR}/swupdate-${SWUPDATE_VER}/include/config/auto.conf

if grep -qF 'CONFIG_SIGNED_IMAGES=y' "${SWUPDATE_CONF}"; then
	mkdir -p "${TARGET_DIR}"/etc/swupdate/conf.d
	if grep -qF 'CONFIG_SIGALG_CMS=y' "${SWUPDATE_CONF}"; then
		cp "${KEYS_DIR}"/dev.crt "${TARGET_DIR}"/etc/swupdate/
		# Configure dev.crt if swupdate CMS is enabled
		# shellcheck disable=SC2016
		echo 'SWUPDATE_ARGS="${SWUPDATE_ARGS} -k /etc/swupdate/dev.crt"' > \
			"${TARGET_DIR}"/etc/swupdate/conf.d/99-signing.conf
	else
		# Configure public key if swupdate signature check is enabled
		# shellcheck disable=SC2016
		echo 'SWUPDATE_ARGS="${SWUPDATE_ARGS} -k /rodata/public/ssl/misc/update.pem"' > \
			"${TARGET_DIR}"/etc/swupdate/conf.d/99-signing.conf
	fi
fi

# Path to common image files
CCONF_DIR=${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/image
CSCRIPT_DIR=${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common

# Configure keys, boot script, and SWU tools when using encrypted toolkit
if ${SECURE_BOOT} ; then
	# Copy keys if present
	if [ -f "${KEYS_DIR}/dev.key" ]; then
		rm -rf "${BINARIES_DIR}/keys"
		ln -rsf "${KEYS_DIR}" "${BINARIES_DIR}/keys"
	fi

	export UBOOT_SIGN_ENABLE='1'
	export UBOOT_SIGN_KEYNAME='dev'
fi

export UBOOT_SCRIPT='boot.scr'

kver=$(make --no-print-directory -C "${BUILD_DIR}/linux-${LINUX_VER}" kernelrelease \
	| sed '/^make\[/d')
export FIT_SUMMIT_VERSION=Linux-${kver}-${BR2_SUMMIT_BUILD_VERSION}

ENV_SIZE=$(sed -rn 's,^CONFIG_ENV_SIZE=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")
ENV_OFFSET=$(sed -rn 's,^CONFIG_ENV_OFFSET=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")
TEXT_BASE=$(sed -rn 's,^CONFIG_TEXT_BASE=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")

create_fw_env_emmc_sd() {
	echo "/dev/mmcblk0boot0 ${ENV_OFFSET} ${ENV_SIZE}" > "${TARGET_DIR}/etc/fw_env_emmc-a.config"
	echo "/dev/mmcblk0boot1 ${ENV_OFFSET} ${ENV_SIZE}" > "${TARGET_DIR}/etc/fw_env_emmc-b.config"
	echo "/boot/uboot.env 0 ${ENV_SIZE}" > "${TARGET_DIR}/etc/fw_env_sd.config"
}

rm -f "${TARGET_DIR}/etc/fw_env.config"
touch "${TARGET_DIR}/etc/fw_env.config"

case "${BUILD_TYPE}" in
	wb50n*|som60*|ig60*)
		# Copy the u-boot.its
		rm -f "${BINARIES_DIR}/u-boot.its"
		if ${SECURE_BOOT} ; then
			cp -f "${CCONF_DIR}/u-boot-enc.its" "${BINARIES_DIR}/u-boot.its"
		else
			cp -f "${CCONF_DIR}/u-boot.its" "${BINARIES_DIR}/u-boot.its"
		fi
		sed -r -i "s/load = <.*>;/load = <${TEXT_BASE}>;/" "${BINARIES_DIR}/u-boot.its"

		for i in a b ; do
			echo "/dev/mtd:u-boot-env-${i} 0x00000 ${ENV_SIZE} 0x20000"
		done > "${TARGET_DIR}/etc/fw_env_flash.config"

		case "${BUILD_TYPE}" in
			wb50n*)
				rm -f "${TARGET_DIR}/usr/lib/NetworkManager/system-connections/eth1.nmconnection"
				;;
			ig60)
				ENCRYPTED_TOOLKIT=true
				;;
		esac

		if ${SD} ; then
			if ! ${ENCRYPTED_TOOLKIT} && ! grep -qF "swap" "${TARGET_DIR}/etc/fstab"; then
				echo '/dev/mmcblk0p2 none swap defaults 0 0' >> "${TARGET_DIR}/etc/fstab"
			fi

			mkdir -p "${TARGET_DIR}/boot"
			echo "/boot/uboot.env 0 ${ENV_SIZE}" > "${TARGET_DIR}/etc/fw_env_sd.config"

			# Copy mksdcard.sh and mksdimg.sh to images
			ln -rsf "${CSCRIPT_DIR}/mksdcard.sh" "${BINARIES_DIR}/mksdcard.sh"
			ln -rsf "${CSCRIPT_DIR}/mksdimg.sh" "${BINARIES_DIR}/mksdimg.sh"
		else
			ln -rsf "${BOARD_DIR}/configs/sw-description" "${BINARIES_DIR}/sw-description"
			ln -rsf "${CSCRIPT_DIR}/erase_data.sh" "${BINARIES_DIR}/erase_data.sh"
		fi

		export linux_comp='gzip'
		export UBOOT_LOADADDRESS=0x20008000
		export UBOOT_ENTRYPOINT=0x20008000
		export FDT_LOADADDRESS=
		export UBOOT_ARCH='arm'
		export KERNEL_IMAGE='Image.gz'
		;;

	*imx8*)
		mkdir -p "${TARGET_DIR}/boot"
		create_fw_env_emmc_sd

		ln -rsf "${CSCRIPT_DIR}/mksdcard.sh" "${BINARIES_DIR}/mksdcard.sh"
		ln -rsf "${CSCRIPT_DIR}/mksdimg.sh" "${BINARIES_DIR}/mksdimg.sh"
		ln -rsf "${CSCRIPT_DIR}/erase_data_emmc.sh" "${BINARIES_DIR}/erase_data.sh"
		ln -rsf "${BOARD_DIR}/configs/sw-description" "${BINARIES_DIR}/sw-description"

		export linux_comp='zstd'
		export UBOOT_LOADADDRESS=0x40400000
		export UBOOT_ENTRYPOINT=0x40400000
		export FDT_LOADADDRESS=0x43000000
		export UBOOT_ARCH='arm64'
		export KERNEL_IMAGE='Image.zst'
		export FIT_PAD_ALG='pss'
		;;

	*am62*)
		mkdir -p "${TARGET_DIR}/boot"
		create_fw_env_emmc_sd

		ln -rsf "${CSCRIPT_DIR}/mksdcard.sh" "${BINARIES_DIR}/mksdcard.sh"
		ln -rsf "${CSCRIPT_DIR}/mksdimg.sh" "${BINARIES_DIR}/mksdimg.sh"
		ln -rsf "${CSCRIPT_DIR}/erase_data_emmc.sh" "${BINARIES_DIR}/erase_data.sh"
		ln -rsf "${BOARD_DIR}/configs/sw-description" "${BINARIES_DIR}/sw-description"

		export linux_comp='zstd'
		export UBOOT_LOADADDRESS=0x81000000
		export UBOOT_ENTRYPOINT=0x81000000
		export UBOOT_DTB_LOADADDRESS=0x83800000
		export UBOOT_DTBO_LOADADDRESS=0x83880000
		export UBOOT_ARCH='arm64'
		export KERNEL_IMAGE='Image.zst'
		export FIT_PAD_ALG='pss'
		;;
esac

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/kernel-fitimage.sh" "${BINARIES_DIR}/kernel.its"

printf '%s\n%s\n' "${kver}" '6.6.0' | sort --sort=version | head -n1 | \
	grep -qF '6.6.0' && OLD_KERNEL=false || OLD_KERNEL=true
export OLD_KERNEL

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/generate_boot_script.sh" > "${BINARIES_DIR}/boot.scr"

case "${BUILD_TYPE}" in
	wb50n*) SOM=wb50n ;;
	som60*|ig60*) SOM=som60 ;;
esac

case $(sed -rn 's/BR2_SUMMIT_FIPS_([0-9]+)=y/\1/p' "${BR2_CONFIG}") in
	11)
		install -D -m 0644 -t "${TARGET_DIR}/usr/lib/fipscheck" \
			"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/fips_hash/11.0/${SOM}/"*
		;;
esac

if grep -qF 'BR2_TARGET_GENERIC_ROOT_PASSWD=""' "${BR2_CONFIG}" && \
   grep -qF 'BR2_TARGET_ENABLE_ROOT_LOGIN=y' "${BR2_CONFIG}"
then
	if [ -f "${TARGET_DIR}/etc/inittab" ]; then
		sed -i 's,^.*/getty.*,::respawn:-/bin/sh,' \
			"${TARGET_DIR}/etc/inittab"
	else
		sed -i 's,/agetty -o,/agetty -a root -o,g' \
			"${TARGET_DIR}/usr/lib/systemd/system/serial-getty@.service"
	fi
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST BUILD COMMON script: done."
