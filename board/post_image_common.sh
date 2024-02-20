BUILD_TYPE="${1}"

echo "COMMON POST IMAGE script: starting..."

# enable tracing and exit on errors
set -x -e

[ -n "${BR2_LRD_PRODUCT}" ] || \
	BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

if grep -qF "BR2_LINUX_KERNEL_IMAGE_TARGET_CUSTOM=y" ${BR2_CONFIG}; then

# Tooling checks
mkimage=${BUILD_DIR}/uboot-custom/tools/mkimage
fipshmac=${HOST_DIR}/bin/fipshmac

[ -x ${mkimage} ] || \
	die "No mkimage found (uboot has not been built?)"

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

hash_check() {
	${fipshmac} ${1}/${2}
	if [ "$(cat ${1}/.${2}.hmac)" == "$(cat ${TARGET_DIR}/usr/lib/fipscheck/${2}.hmac)" ]; then
		rm ${1}/.${2}.hmac
	else
		rm ${1}/.${2}.hmac
		echo "FIPS Hash mismatch to the certified for ${2}"
		exit 1
	fi
}

if grep -qF "BR2_PACKAGE_SUMMITSSL_FIPS_BINARIES=y" ${BR2_CONFIG} ||\
   grep -qF "BR2_PACKAGE_LAIRD_OPENSSL_FIPS=y" ${BR2_CONFIG}
then
	hash_check ${BINARIES_DIR} ${IMAGE_NAME}
	hash_check ${TARGET_DIR}/usr/bin fipscheck
	hash_check ${TARGET_DIR}/usr/lib libfipscheck.so.1
	hash_check ${TARGET_DIR}/usr/lib libcrypto.so.1.0.0
elif grep -qF "BR2_PACKAGE_LAIRD_OPENSSL_3_0_FIPS_BINARIES=y" ${BR2_CONFIG} ||\
     grep -qF "BR2_PACKAGE_LIBOPENSSL_ENABLE_FIPS=y" ${BR2_CONFIG}
then
	hash_check ${BINARIES_DIR} ${IMAGE_NAME}
	hash_check ${TARGET_DIR}/usr/bin fipscheck
	hash_check ${TARGET_DIR}/usr/lib libfipscheck.so.1
	hash_check ${TARGET_DIR}/usr/lib/ossl-modules fips.so
fi

ln -rsf "${BINARIES_DIR}/kernel.itb" "${BINARIES_DIR}/kernel.bin"

(cd "${BINARIES_DIR}" && ${mkimage} -f kernel.its kernel.itb)

else

ln -rsf "${BINARIES_DIR}/uImage"* "${BINARIES_DIR}/kernel.bin"

fi

ln -rsf ${BR2_EXTERNAL_LRD_SOM_PATH}/board/rootfs-additions-common/usr/sbin/fw_select "${BINARIES_DIR}/fw_select"
ln -rsf "${TARGET_DIR}"/usr/sbin/fw_update "${BINARIES_DIR}/fw_update"
ln -rsf "${BINARIES_DIR}/boot.bin" "${BINARIES_DIR}/at91bs.bin"
ln -rsf "${BINARIES_DIR}/rootfs.ubi" "${BINARIES_DIR}/rootfs.bin"

if [ "${BUILD_TYPE}" = wb50n ]; then
	ln -rsf ${BR2_EXTERNAL_LRD_SOM_PATH}/board/wb50n/configs/sw-description "${BINARIES_DIR}/sw-description"
	ALL_SWU_FILES="sw-description boot.bin u-boot.bin"
	SWU_BOOT=${BR2_LRD_PRODUCT}-boot.swu
	( cd ${BINARIES_DIR} && \
		echo -e "${ALL_SWU_FILES// /\\n}" | cpio -ovL -H crc > ${BINARIES_DIR}/${SWU_BOOT})
fi

[ -n "${LAIRD_FW_TXT_URL}" ] || \
	LAIRD_FW_TXT_URL="http://$(hostname)/${BR2_LRD_PRODUCT}"

${BR2_EXTERNAL_LRD_SOM_PATH}/board/mkfwtxt.sh "${LAIRD_FW_TXT_URL}" "${BINARIES_DIR}"
${BR2_EXTERNAL_LRD_SOM_PATH}/board/mkfwusi.sh

if [ ! -x ${TARGET_DIR}/usr/bin/dcas ]; then
    sed '/\/etc\/dcas.conf/d' -i ${BINARIES_DIR}/fw.txt
fi

size_check () {
	[ $(stat -Lc "%s" ${BINARIES_DIR}/${1}) -le $((${2}*128*1024)) ] || \
		{ echo "${1} size exceeded ${2} block limit, failed"; exit 1; }
}

case "${BUILD_TYPE}" in
	"wb50n") limit=38 ;;
	"wb45n") limit=18 ;;
	"wb40n") limit=38 ;;
	*)       exit 1   ;;
esac

size_check 'kernel.bin' ${limit}
size_check 'u-boot.bin' 3

[ -z "${VERSION}" ] || RELEASE_SUFFIX="-${VERSION}"

tar -cjhf "${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird${RELEASE_SUFFIX}.tar.bz2" \
	--owner=root --group=root -C "${BINARIES_DIR}" \
	at91bs.bin u-boot.bin kernel.bin rootfs.bin \
	fw_update fw_select fw_usi fw.txt ${SWU_BOOT}

echo "COMMON POST IMAGE script: done."
