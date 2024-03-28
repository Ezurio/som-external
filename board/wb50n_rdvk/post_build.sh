BOARD_DIR="$(realpath $(dirname $0))"
BUILD_TYPE="${2}"

BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: starting..."

set -x -e

LOCRELSTR="${LAIRD_RELEASE_STRING}"
if [ -z "${LOCRELSTR}" ] || [ "${LOCRELSTR}" == "0.0.0.0" ]; then
	LOCRELSTR="Summit Linux development build 0.${BR2_LRD_BRANCH}.0.0 $(date +%Y%m%d)"
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

# Copy the product specific rootfs additions
rsync -rlptDWK --no-perms --exclude=.empty "${BOARD_DIR}/rootfs-additions/" "${TARGET_DIR}"
cp "${BOARD_DIR}/../rootfs-additions-common/usr/sbin/fw_"* "${TARGET_DIR}/usr/sbin"
cp "${BOARD_DIR}/../rootfs-additions-common/etc/init.d/S25platform" "${TARGET_DIR}/etc/init.d"
cp "${BOARD_DIR}/../rootfs-additions-common/usr/sbin/fipsInit.sh"* "${TARGET_DIR}/usr/sbin"

rm -f \
	${TARGET_DIR}/etc/init.d/S20urandom \
	${TARGET_DIR}/etc/init.d/S40bluetooth \
	${TARGET_DIR}/etc/init.d/S80dnsmasq \
	${TARGET_DIR}/etc/init.d/S30adaptive_ww

mkdir -p ${TARGET_DIR}/etc/NetworkManager/system-connections

# Make sure connection files have proper attributes
for f in ${TARGET_DIR}/etc/NetworkManager/system-connections/* ; do
	if [ -f "${f}" ] ; then
		chmod 600 "${f}"
	fi
done

# Make sure dispatcher files have proper attributes
for f in ${TARGET_DIR}/etc/NetworkManager/dispatcher.d/* ; do
	if [ -f "${f}" ] ; then
		chmod 700 "${f}"
	fi
done

# Fixup and add debugfs to fstab
grep -q "/sys/kernel/debug" ${TARGET_DIR}/etc/fstab ||\
	echo 'nodev /sys/kernel/debug   debugfs   defaults   0  0' >> ${TARGET_DIR}/etc/fstab

CCONF_DIR="$(realpath ${BR2_EXTERNAL_LRD_SOM_PATH}/board/configs-common/image)"

# Generate kernel FIT image script
# kernel.its references zImage and at91-dvk_som60.dtb, and all three
# files must be in current directory for mkimage.
DTB="$(sed -n 's/^BR2_LINUX_KERNEL_INTREE_DTS_NAME="\(.*\)"$/\1/p' ${BR2_CONFIG})"
# Look for DTB in custom path
[ -n "${DTB}" ] || \
	DTB="$(sed 's,BR2_LINUX_KERNEL_CUSTOM_DTS_PATH="\(.*\)",\1,; s,\s,\n,g' ${BR2_CONFIG} | sed -n 's,.*/\(.*\).dts$,\1,p')"

DTB="${DTB##*/}"

sed "s/at91-wb50n/${DTB}/g" ${CCONF_DIR}/kernel_legacy.its > ${BINARIES_DIR}/kernel.its

echo "${BR2_LRD_PRODUCT^^} POST BUILD script: done."
