BOARD_DIR="${1}"
BUILD_TYPE="${2}"
ENCRYPTED_TOOLKIT_DIR="$(realpath ${3})"
fipshmac=${HOST_DIR}/bin/fipshmac

# enable tracing and exit on errors
set -x -e

[ -n "${BR2_LRD_PRODUCT}" ] || \
	BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: starting..."

case "${BUILD_TYPE}" in
*sd) SD=true  ;;
  *) SD=false ;;
esac

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_LRD_ENCRYPTED_STORAGE_TOOLKIT=y" ${BR2_CONFIG} \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false

# Create default firmware description file.
# This may be overwritten by a proper release file.
LOCRELSTR="${LAIRD_RELEASE_STRING}"
if [ -z "${LOCRELSTR}" ] || [ "${LOCRELSTR}" = "0.0.0.0" ]; then
	LOCRELSTR="Summit Linux development build 0.${BR2_LRD_BRANCH}.0.0-$(/bin/date +%Y%m%d%H%M)"
fi
echo "${LOCRELSTR}" > "${TARGET_DIR}/etc/issue"

[ -z "${VERSION}" ] && LOCVER="0.${BR2_LRD_BRANCH}.0.0" || LOCVER="${VERSION}"

echo -ne \
"NAME=\"Summit Linux\"\n"\
"VERSION=\"${LOCRELSTR}\"\n"\
"ID=${BR2_LRD_PRODUCT}\n"\
"VERSION_ID=${LOCVER}\n"\
"BUILD_ID=${LOCRELSTR##* }\n"\
"PRETTY_NAME=\"${LOCRELSTR}\"\n"\
>  "${TARGET_DIR}/usr/lib/os-release"

# Copy the product specific rootfs additions, strip host user access control
rsync -rlptDWK --no-perms --exclude=.empty "${BOARD_DIR}/rootfs-additions/" "${TARGET_DIR}"

if ${SD}; then
	if [ -f ${TARGET_DIR}/usr/lib/libsystemd.so ]; then
		echo '/dev/root / auto rw,noatime 0 1' > ${TARGET_DIR}/etc/fstab
		echo '/dev/mmcblk0p2 none swap defaults 0 0' >> ${TARGET_DIR}/etc/fstab
		echo '/dev/mmcblk0p1 /boot vfat rw,noexec,nosuid,nodev,noatime 0 0' >> ${TARGET_DIR}/etc/fstab
	elif ! grep -qF "/boot" ${TARGET_DIR}/etc/fstab; then
		echo '/dev/mmcblk0p2 none swap defaults 0 0' >> ${TARGET_DIR}/etc/fstab
		echo '/dev/mmcblk0p1 /boot vfat rw,noexec,nosuid,nodev,noatime 0 0' >> ${TARGET_DIR}/etc/fstab
		mkdir -p ${TARGET_DIR}/boot
	fi

	sed -i 's,^/dev/mtd,# /dev/mtd,' ${TARGET_DIR}/etc/fw_env.config
else
	echo '/dev/root / auto ro 0 0' > ${TARGET_DIR}/etc/fstab
	sed -i 's,^/boot/,# /boot/,' ${TARGET_DIR}/etc/fw_env.config
fi

if ${ENCRYPTED_TOOLKIT} || [ "${BUILD_TYPE}" = ig60 ]; then
	# Securely mount /var on tmpfs
	echo "tmpfs /var tmpfs mode=1777,noexec,nosuid,nodev,noatime 0 0" >> ${TARGET_DIR}/etc/fstab
fi

# No need to detect SmartMedia cards, thus remove errors and speedup boot
rm -f ${TARGET_DIR}/usr/lib/udev/rules.d/75-probe_mtd.rules

# Fixup systemd default to avoid errors
if [ -f ${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf ]; then
	sed -i 's/^net\.core\.default_qdisc/# net\.core\.default_qdisc/' ${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf
	sed -i 's/^kernel\.sysrq/# kernel\.sysrq/' ${TARGET_DIR}/usr/lib/sysctl.d/50-default.conf
fi

if [ -x ${TARGET_DIR}/usr/sbin/NetworkManager ]; then

mkdir -p ${TARGET_DIR}/etc/NetworkManager/system-connections

# Make sure connection files have proper attributes
for f in ${TARGET_DIR}/etc/NetworkManager/system-connections/* ; do
	if [ -f "${f}" ] ; then
		chmod 600 "${f}"
	fi
done

# Make sure dispatcher files have proper attributes
[ -d ${TARGET_DIR}/etc/NetworkManager/dispatcher.d ] && \
	find ${TARGET_DIR}/etc/NetworkManager/dispatcher.d -type f -exec chmod 700 {} \;

if [ -x ${TARGET_DIR}/usr/sbin/firewalld ]; then
	sed -i "s/firewall-backend=.*/firewall-backend=none/g" ${TARGET_DIR}/etc/NetworkManager/NetworkManager.conf
fi

ln -sf /run/NetworkManager/resolv.conf ${TARGET_DIR}/etc/resolv.conf

fi

# Remove not needed systemd generators
rm -f ${TARGET_DIR}/usr/lib/systemd/system-generators/systemd-gpt-auto-generator
rm -f ${TARGET_DIR}/usr/lib/systemd/systemd-network-generator
rm -f ${TARGET_DIR}/usr/lib/systemd/system/systemd-network-generator.service
rm -f ${TARGET_DIR}/usr/lib/systemd/system/sys-fs-fuse-connections.mount

if [ -f ${TARGET_DIR}/usr/lib/systemd/system/systemd-logind.service ] && \
   ! grep -qF "BR2_PACKAGE_LIBDRM=y" ${BR2_CONFIG}; then
	sed -i 's/modprobe@drm.service//g' ${TARGET_DIR}/usr/lib/systemd/system/systemd-logind.service
fi

# Remove bluetooth support when BlueZ 5 not present
if [ ! -x ${TARGET_DIR}/usr/bin/btattach ]; then
	rm -rf ${TARGET_DIR}/etc/bluetooth
	rm -f ${TARGET_DIR}/etc/udev/rules.d/80-btattach.rules
	rm -f ${TARGET_DIR}/usr/lib/systemd/system/btattach.service
	rm -f ${TARGET_DIR}/usr/bin/bt-service.sh
	rm -f ${TARGET_DIR}/usr/bin/bttest.sh
else
	# Customize BlueZ Bluetooth advertised name
	if [ -e ${TARGET_DIR}/etc/bluetooth/main.conf ]; then
		sed -i "s/.*Name *=.*/Name = Summit-${BR2_LRD_PRODUCT^^}/" ${TARGET_DIR}/etc/bluetooth/main.conf
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
rm -f "${TARGET_DIR}/usr/lib/python3.10/ensurepip/_bundled/"*.whl
rm -f "${TARGET_DIR}/usr/lib/python3.10/distutils/command/"*.exe
rm -f "${TARGET_DIR}/usr/lib/python3.10/site-packages/setuptools/"*.exe
rm -rf "${TARGET_DIR}/usr/lib/python3.10/site-packages/"*.egg-info
[ -d "${TARGET_DIR}/usr/lib/node_modules" ] && \
	find "${TARGET_DIR}/usr/lib/node_modules" -name '*.md' -exec rm -f {} \;
rm -rf "${TARGET_DIR}/var/www/swupdate"
rm -rf "${TARGET_DIR}/usr/share/gobject-introspection-1.0/"
rm -rf "${TARGET_DIR}/usr/lib/gobject-introspection/"

rm -f ${TARGET_DIR}/usr/lib/systemd/system/swupdate-progress.service
rm -f ${TARGET_DIR}/usr/lib/swupdate/conf.d/90-start-progress

# No need to start swupdate service automatically, it will start by socket
if [ -f ${TARGET_DIR}/usr/lib/systemd ]; then
	echo "disable swupdate.service" > ${TARGET_DIR}/usr/lib/systemd/system-preset/50-swupdate.preset
fi

if [ "${BUILD_TYPE}" != ig60 ]; then

# Configure public key if swupdate signature check is enabled
if grep -q 'CONFIG_SIGNED_IMAGES=y' ${BUILD_DIR}/swupdate*/include/config/auto.conf; then
	mkdir -p ${TARGET_DIR}/etc/swupdate/conf.d
	echo 'SWUPDATE_ARGS="${SWUPDATE_ARGS} -k /rodata/public/ssl/misc/update.pem"' > ${TARGET_DIR}/etc/swupdate/conf.d/99-signing.conf
fi

# Path to common image files
CCONF_DIR="$(realpath $BR2_EXTERNAL_LRD_SOM_PATH/board/configs-common/image)"
CSCRIPT_DIR="$(realpath $BR2_EXTERNAL_LRD_SOM_PATH/board/scripts-common)"

# Configure keys, boot script, and SWU tools when using encrypted toolkit
if ${ENCRYPTED_TOOLKIT} ; then
	# Copy keys if present
	if [ -f ${ENCRYPTED_TOOLKIT_DIR}/dev.key ]; then
		ln -rsf ${ENCRYPTED_TOOLKIT_DIR} ${BINARIES_DIR}
	fi

	# Copy the u-boot.its
	ln -rsf ${CCONF_DIR}/u-boot-enc.its ${BINARIES_DIR}/u-boot.its
	# Use verity boot script
	ln -rsf ${CCONF_DIR}/boot_verity.scr ${BINARIES_DIR}/boot.scr

	cp -f ${CCONF_DIR}/kernel-enc.its ${BINARIES_DIR}/kernel.its
else
	# Copy the u-boot.its
	ln -rsf ${CCONF_DIR}/u-boot.its ${BINARIES_DIR}/u-boot.its
	# Use standard boot script
	ln -rsf ${CCONF_DIR}/boot.scr ${BINARIES_DIR}/boot.scr

	cp -f ${CCONF_DIR}/kernel.its ${BINARIES_DIR}/kernel.its
fi

if ${SD} ; then
	ln -rsf ${CCONF_DIR}/boot_mmc.scr ${BINARIES_DIR}/boot.scr
	ln -rsf ${CCONF_DIR}/u-boot_mmc.scr ${BINARIES_DIR}/u-boot.scr

	# Copy mksdcard.sh and mksdimg.sh to images
	ln -rsf ${CSCRIPT_DIR}/mksdcard.sh ${BINARIES_DIR}/mksdcard.sh
	ln -rsf ${CSCRIPT_DIR}/mksdimg.sh ${BINARIES_DIR}/mksdimg.sh
else
	# Copy scripts for SWU generation
	case "${BUILD_TYPE}" in
	som60x2*)
		ln -rsf ${BOARD_DIR}/configs/sw-description-som60x2 ${BINARIES_DIR}/sw-description
		;;
	*)
		ln -rsf ${BOARD_DIR}/configs/sw-description ${BINARIES_DIR}/sw-description
		;;
	esac

	ln -rsf ${CSCRIPT_DIR}/erase_data.sh ${BINARIES_DIR}/erase_data.sh
	ln -rsf ${CCONF_DIR}/u-boot.scr ${BINARIES_DIR}/u-boot.scr
fi

ln -rsf ${CCONF_DIR}/u-boot.scr.its ${BINARIES_DIR}/u-boot.scr.its

# Generate kernel FIT image script
# kernel.its references zImage and at91-dvk_som60.dtb, and all three
# files must be in current directory for mkimage.
DTB="$(sed -n 's/^BR2_LINUX_KERNEL_INTREE_DTS_NAME="\(.*\)"$/\1/p' ${BR2_CONFIG})"
# Look for DTB in custom path
[ -n "${DTB}" ] || \
	DTB="$(sed 's,BR2_LINUX_KERNEL_CUSTOM_DTS_PATH="\(.*\)",\1,; s,\s,\n,g' ${BR2_CONFIG} | sed -n 's,.*/\(.*\).dts$,\1,p')"

sed -i "s/at91-dvk_som60/${DTB}/g" ${BINARIES_DIR}/kernel.its

fi

if grep -q 'BR2_DEFCONFIG=.*_fips_dev_.*' ${BR2_CONFIG}; then
	IMAGE_NAME=Image

	if grep -q '"Image.gz"' ${BINARIES_DIR}/kernel.its; then
		gzip -9kfn ${BINARIES_DIR}/Image
		IMAGE_NAME+=.gz
	elif grep -q '"Image.lzo"' ${BINARIES_DIR}/kernel.its; then
		lzop -9on ${BINARIES_DIR}/Image.lzo ${BINARIES_DIR}/Image
		IMAGE_NAME+=.lzo
	elif grep -q '"Image.lzma"' ${BINARIES_DIR}/kernel.its; then
		lzma -9kf ${BINARIES_DIR}/Image
		IMAGE_NAME+=.lzma
	elif grep -q '"Image.zstd"' ${BINARIES_DIR}/kernel.its; then
		zstd -19 -kf ${BINARIES_DIR}/Image
		IMAGE_NAME+=.zstd
	fi

	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${BINARIES_DIR}/${IMAGE_NAME}
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/bin/fipscheck
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/lib/libfipscheck.so.1
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/lib/ossl-modules/fips.so
	rm -f ${TARGET_DIR}/usr/lib/fipscheck/libcrypto.so.1.0.0.hmac
fi

if grep -qF 'BR2_TARGET_GENERIC_ROOT_PASSWD=""' ${BR2_CONFIG} && \
   grep -qF BR2_TARGET_ENABLE_ROOT_LOGIN=y ${BR2_CONFIG}
then

if [ -f ${TARGET_DIR}/etc/inittab ]; then
	sed -i -e 's,^.*/getty.*,::respawn:-/bin/sh,' ${TARGET_DIR}/etc/inittab
else
	sed -i -e 's,/agetty -o,/agetty -a root -o,g' ${TARGET_DIR}/usr/lib/systemd/system/serial-getty@.service
fi

fi

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: done."
