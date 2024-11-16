#! /bin/bash

BUILD_TYPE="${1}"

echo "COMMON POST IMAGE script: starting..."

# enable tracing and exit on errors
set -x -e

[ -n "${BR2_SUMMIT_PRODUCT}" ] || \
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

if grep -qF "BR2_LINUX_KERNEL_IMAGE_TARGET_CUSTOM=y" "${BR2_CONFIG}"; then

# Tooling checks
mkimage=${BUILD_DIR}/uboot-custom/tools/mkimage

[ -x "${mkimage}" ] || \
	die "No mkimage found (uboot has not been built?)"

IMAGE_NAME=$(sed -rn 's/.*"(Image.*)".*/\1/p' "${BINARIES_DIR}/kernel.its")

case "${IMAGE_NAME}" in
	Image.gz) gzip -9kfn "${BINARIES_DIR}/Image" ;;
	Image.lzo) lzop -9on "${BINARIES_DIR}/Image".lzo "${BINARIES_DIR}/Image" ;;
	Image.lzma) lzma -9kf "${BINARIES_DIR}/Image" ;;
	Image.zst) zstd -9 -kf "${BINARIES_DIR}/Image" -o "${BINARIES_DIR}/Image.zst" ;;
esac

hash_check() {
	for i in "$@"; do
		openssl mac -macopt key:orboDeJITITejsirpADONivirpUkvarP -digest sha256 -in  "${i}" hmac | \
			diff -is - "${TARGET_DIR}/usr/lib/fipscheck/${i##*/}.hmac" || \
			die "FIPS Hash mismatch to the certified for ${i##*/}"
	done
}

if grep -qF -e "BR2_PACKAGE_SUMMITSSL_FIPS_BINARIES=y" -e "BR2_PACKAGE_SUMMIT_OPENSSL_FIPS=y" "${BR2_CONFIG}"
then
	hash_check \
		"${BINARIES_DIR}/${IMAGE_NAME}" \
		"${TARGET_DIR}/usr/bin/fipscheck" \
		"${TARGET_DIR}/usr/lib/libfipscheck.so.1" \
		"${TARGET_DIR}/usr/lib/libcrypto.so.1.0.0"
elif grep -qF -e "BR2_PACKAGE_SUMMIT_OPENSSL_FIPS_PROVIDER=y" -e "BR2_PACKAGE_LIBOPENSSL_ENABLE_FIPS=y" "${BR2_CONFIG}"
then
	hash_check \
		"${BINARIES_DIR}/${IMAGE_NAME}" \
		"${TARGET_DIR}/usr/bin/fipscheck" \
		"${TARGET_DIR}/usr/lib/libfipscheck.so.1" \
		"${TARGET_DIR}/usr/lib/ossl-modules/fips.so"
fi

ln -rsf "${BINARIES_DIR}/kernel.itb" "${BINARIES_DIR}/kernel.bin"

(cd "${BINARIES_DIR}" && ${mkimage} -f kernel.its kernel.itb)

else

ln -rsf "${BINARIES_DIR}/uImage"* "${BINARIES_DIR}/kernel.bin"

fi

ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/rootfs-additions-common/usr/sbin/fw_select" "${BINARIES_DIR}/fw_select"
ln -rsf "${TARGET_DIR}"/usr/sbin/fw_update "${BINARIES_DIR}/fw_update"
ln -rsf "${BINARIES_DIR}/boot.bin" "${BINARIES_DIR}/at91bs.bin"
ln -rsf "${BINARIES_DIR}/rootfs.ubi" "${BINARIES_DIR}/rootfs.bin"

if [ "${BUILD_TYPE}" = wb50n ]; then
	ln -rsf "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/wb50n/configs/sw-description" "${BINARIES_DIR}/sw-description"
	ALL_SWU_FILES="sw-description boot.bin u-boot.bin"
	SWU_BOOT=${BR2_SUMMIT_PRODUCT}-boot.swu
	( cd "${BINARIES_DIR}" && \
		echo -e "${ALL_SWU_FILES// /\\n}" | cpio -ovL -H crc > "${BINARIES_DIR}/${SWU_BOOT}")
else
	SWU_BOOT=""
fi

"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/mkfwtxt.sh" "${BR2_SUMMIT_PRODUCT}-${BR2_SUMMIT_BUILD_VERSION}"
"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/mkfwusi.sh"

if [ ! -x "${TARGET_DIR}/usr/bin/dcas" ]; then
    sed '/\/etc\/dcas.conf/d' -i "${BINARIES_DIR}/fw.txt"
fi

size_check () {
	[ "$(stat -Lc "%s" "${BINARIES_DIR}/${1}")" -le $((${2}*128*1024)) ] || \
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

# shellcheck disable=SC2086
tar -cjhSf "${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}-summit-${BR2_SUMMIT_BUILD_VERSION}.tar.bz2" \
	--owner=root --group=root -C "${BINARIES_DIR}" \
	at91bs.bin u-boot.bin kernel.bin rootfs.bin \
	fw_update fw_select fw_usi fw.txt ${SWU_BOOT}

echo "COMMON POST IMAGE script: done."
