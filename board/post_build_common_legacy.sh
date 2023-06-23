BUILD_TYPE="${1}"

echo "COMMON POST BUILD legacy script: starting..."

# enable tracing and exit on errors
set -x -e

[ -z "${BR2_LRD_PRODUCT}" ] && \
	BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

# remove default ssh init file
# real version is in init.d/opt and works w/ inetd or standalone
rm -f ${TARGET_DIR}/etc/init.d/S50sshd

# remove default init scripts, they are replaced
rm -f ${TARGET_DIR}/etc/init.d/S50lighttpd
rm -f ${TARGET_DIR}/etc/init.d/S20urandom
rm -f ${TARGET_DIR}/etc/init.d/S40network
rm -f ${TARGET_DIR}/etc/init.d/S41dhcpcd
rm -f ${TARGET_DIR}/etc/init.d/S40bluetoothd
rm -f ${TARGET_DIR}/etc/init.d/S35iptables 

# remove perl cruft
rm -f ${TARGET_DIR}/etc/ssl/misc/tsget
rm -f ${TARGET_DIR}/etc/ssl/misc/CA.pl
rm -f ${TARGET_DIR}/usr/bin/pcf2vpnc
rm -f ${TARGET_DIR}/usr/bin/chkdupexe

# remove debian cruft
rm -fr ${TARGET_DIR}/etc/network/if-*

# Copy the rootfs-additions-common in place first.
# If necessary, these can be overwritten by the product specific rootfs-additions.
rsync -rlptDWK --no-perms --exclude=.empty "${BR2_EXTERNAL_LRD_SOM_PATH}/board/rootfs-additions-common/" "${TARGET_DIR}"

# Copy the board specific rootfs additions
case "${BUILD_TYPE}" in
	"wb50n" | "wb45n")
		rsync -rlptDWK --no-perms --exclude=.empty "${BR2_EXTERNAL_LRD_SOM_PATH}/board/${BUILD_TYPE}/rootfs-additions/" "${TARGET_DIR}"
		;;
esac

# install libnl*.so.3 links
ln -rsf ${TARGET_DIR}/usr/lib/libnl-3.so ${TARGET_DIR}/usr/lib/libnl.so.3
ln -rsf ${TARGET_DIR}/usr/lib/libnl-genl-3.so ${TARGET_DIR}/usr/lib/libnl-genl.so.3

# create missing symbolic link
# TODO: shouldn't have to do this here, temporary workaround
ln -rsf ${TARGET_DIR}/usr/lib/libsdc_sdk.so.1.0 ${TARGET_DIR}/usr/lib/libsdc_sdk.so.1

# wireless.sh won't be able to create this with the ro file system
ln -rsf ${TARGET_DIR}/etc/network/wireless.sh ${TARGET_DIR}/sbin/wireless

# Services to disable by default
[ -f ${TARGET_DIR}/etc/init.d/S??lighttpd ] && \
	chmod a-x ${TARGET_DIR}/etc/init.d/S??lighttpd

# Remove the custom bluetooth init-script if bluez utility is not included
if [ -x ${TARGET_DIR}/usr/bin/hciconfig ]; then
	# background the bluetooth init-script
	mv ${TARGET_DIR}/etc/init.d/S95bluetooth ${TARGET_DIR}/etc/init.d/S95bluetooth.bg

	# Customize BlueZ Bluetooth advertised name
	if [ -e ${TARGET_DIR}/etc/bluetooth/main.conf ]; then
		sed -i "s/.*Name *=.*/Name = Laird-${BR2_LRD_PRODUCT^^}/" ${TARGET_DIR}/etc/bluetooth/main.conf
	fi
else
	rm -f ${TARGET_DIR}/etc/init.d/S95bluetooth*
	rm -f ${TARGET_DIR}/usr/bin/bttest.sh
fi

if [ ! -x ${TARGET_DIR}/usr/sbin/hostapd ]; then
	rm -rf ${TARGET_DIR}/etc/hostapd
	rm -rf ${TARGET_DIR}/bin/hostapd_mode
fi

if [ ! -x ${TARGET_DIR}/usr/sbin/lighttpd ]; then
	rm -f ${TARGET_DIR}/sbin/lighty*
	rm -f ${TARGET_DIR}/etc/init.d/opt/S50lighty
	rm -f ${TARGET_DIR}/etc/init.d/S99lighttpd
	sed -i 's/^http/#http/' ${TARGET_DIR}/etc/inetd.conf
fi

if [ ! -x ${TARGET_DIR}/usr/sbin/proftpd ]; then
	sed -i 's/^ftp/#ftp/' ${TARGET_DIR}/etc/inetd.conf
fi

if [ ! -x ${TARGET_DIR}/usr/sbin/pppd ]; then
	rm -f ${TARGET_DIR}/etc/init.d/opt/S45pppd
fi

if [ ! -x ${TARGET_DIR}/usr/sbin/sshd ]; then
	rm -f ${TARGET_DIR}/etc/init.d/opt/S50sshd
	sed -i 's/^ssh/#ssh/' ${TARGET_DIR}/etc/inetd.conf
fi

[ -n "$(find "${TARGET_DIR}/lib/modules/" -name ohci-at91.ko)" ] || \
	rm -f "${TARGET_DIR}/etc/init.d/S37usbhost"

[ -n "$(find "${TARGET_DIR}/lib/modules/" -name cryptodev.ko)" ] || \
	rm -f "${TARGET_DIR}/etc/init.d/S03cryptodev"

if [ -x ${TARGET_DIR}/usr/bin/dcas ]; then

# adjust ssh_config and sshd_config to stop using root and use /etc/ instead.
sed -i "s/AuthorizedKeysFile.*/AuthorizedKeysFile\t\/etc\/.ssh\/authorized_keys/" ${TARGET_DIR}/etc/ssh/sshd_config
echo "IdentityFile /etc/.ssh/identity" >> ${TARGET_DIR}/etc/ssh/ssh_config
echo "IdentityFile /etc/.ssh/id_rsa" >> ${TARGET_DIR}/etc/ssh/ssh_config
echo "IdentityFile /etc/.ssh/id_rsa" >> ${TARGET_DIR}/etc/ssh/ssh_config
echo "UserKnownHostsFile /etc/.ssh/known_hosts" >> ${TARGET_DIR}/etc/ssh/ssh_config

# add SSH directories in /etc/
mkdir -p ${TARGET_DIR}/etc/.ssh
touch ${TARGET_DIR}/etc/.ssh/authorized_keys

# make sure SSH permissions are correct
chmod 700 ${TARGET_DIR}/etc/.ssh
chmod 600 ${TARGET_DIR}/etc/.ssh/authorized_keys

# adjust DCAS SSH location
sed -i "s/dcas_auth_dir.*/dcas_auth_dir=\/etc\/.ssh/" ${TARGET_DIR}/etc/dcas.conf
sed -i "s/DEFAULT_AUTH_DIR=.*/DEFAULT_AUTH_DIR=\/etc\/.ssh/" ${TARGET_DIR}/etc/init.d/opt/S99dcas

fi

# Fixup and add debugfs to fstab
sed -i 's|/dev/root.*|/dev/root	/		auto	rw,noauto,noatime	0	1|' ${TARGET_DIR}/etc/fstab
grep -q "/sys/kernel/debug" ${TARGET_DIR}/etc/fstab ||\
	echo 'nodev		/sys/kernel/debug debugfs defaults	0	0' >> ${TARGET_DIR}/etc/fstab

# create a compressed backup copy of the /e/n/i file
gzip -c ${TARGET_DIR}/etc/network/interfaces >${TARGET_DIR}/etc/network/interfaces~.gz

# Create default firmware description file.
# This may be overwritten by a proper release file.
LOCRELSTR="${LAIRD_RELEASE_STRING}"
if [ -z "${LOCRELSTR}" ] || [ "${LOCRELSTR}" == "0.0.0.0" ]; then
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

if grep -qF "BR2_LINUX_KERNEL_IMAGE_TARGET_CUSTOM=y" ${BR2_CONFIG}; then

CCONF_DIR="$(realpath ${BR2_EXTERNAL_LRD_SOM_PATH}/board/configs-common/image)"

# Generate kernel FIT image script
# kernel.its references Image and at91-wb50n.dtb, and all three
# files must be in current directory for mkimage.
DTB="$(sed -n 's/^BR2_LINUX_KERNEL_INTREE_DTS_NAME="\(.*\)"$/\1/p' ${BR2_CONFIG})"
# Look for DTB in custom path
[ -n "${DTB}" ] || \
	DTB="$(sed 's,BR2_LINUX_KERNEL_CUSTOM_DTS_PATH="\(.*\)",\1,; s,\s,\n,g' ${BR2_CONFIG} | sed -n 's,.*/\(.*\).dts$,\1,p')"

case "${BUILD_TYPE}" in
	"wb50n") EXT=gz   ;;
	"wb45n") EXT=lzma ;;
	*)       exit 1   ;;
esac

sed "s/at91-wb50n/${DTB}/g" ${CCONF_DIR}/kernel_legacy.its > ${BINARIES_DIR}/kernel.its
if [ ${EXT} != gz ]; then
	sed "s/Image.gz/Image.${EXT}/g" -i ${BINARIES_DIR}/kernel.its
	sed "s/gzip/${EXT}/g" -i ${BINARIES_DIR}/kernel.its
fi

kver=$(grep -aom 1 'Linux version [0-9.]\+' ${BINARIES_DIR}/Image)
kver="${kver##* }"
sed "s/summit-version = \"\"/summit-version = \"Linux-${kver}-${LOCVER}\"/g" -i ${BINARIES_DIR}/kernel.its
fi

if grep -q 'BR2_DEFCONFIG=.*_fips_dev_.*' ${BR2_CONFIG}; then
	fipshmac=${HOST_DIR}/bin/fipshmac
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
		zstd -19 -kf ${BINARIES_DIR}/Image -o ${BINARIES_DIR}/Image.zstd
		IMAGE_NAME+=.zstd
	fi

	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${BINARIES_DIR}/${IMAGE_NAME}
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/bin/fipscheck
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/lib/libfipscheck.so.1
	${fipshmac} -d ${TARGET_DIR}/usr/lib/fipscheck/ ${TARGET_DIR}/usr/lib/libcrypto.so.3
	rm -f ${TARGET_DIR}/usr/lib/fipscheck/libcrypto.so.1.0.0.hmac

	sed "s/^auto usb0/#auto usb0/g" -i ${TARGET_DIR}/etc/network/interfaces
fi

echo "COMMON POST BUILD script: done."
