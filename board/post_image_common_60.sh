BOARD_DIR="${1}"
BUILD_TYPE="${2}"

# enable tracing and exit on errors
set -x -e

[ -n "${BR2_LRD_PRODUCT}" ] || \
	export BR2_LRD_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' ${BR2_CONFIG})"

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: starting..."

# Determine if we are building SD card image
case "${BUILD_TYPE}" in
*sd) SD=true  ;;
  *) SD=false ;;
esac

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_LRD_ENCRYPTED_STORAGE_TOOLKIT=y" ${BR2_CONFIG} \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false

grep -qF "BR2_SUMMIT_SECURE_BOOT=y" ${BR2_CONFIG} \
	&& SECURE_BOOT=true || SECURE_BOOT=false

# Tooling checks
mkimage=${BUILD_DIR}/uboot-custom/tools/mkimage
atmel_pmecc_params=${BUILD_DIR}/uboot-custom/tools/atmel_pmecc_params
mkenvimage=${BUILD_DIR}/uboot-custom/tools/mkenvimage
fipshmac=${HOST_DIR}/bin/fipshmac

die() { echo "$@" >&2; exit 1; }

[ -x ${mkimage} ] || \
	die "No mkimage found (uboot has not been built?)"
[ -x ${mkenvimage} ] || \
	die "No mkenvimage found (uboot has not been built?)"

(cd "${BINARIES_DIR}" && "${mkimage}" -f u-boot.scr.its u-boot.scr.itb) || exit 1

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

hash_check() {
	${fipshmac} ${1}/${2}
	if [ "$(cat ${1}/.${2}.hmac)" == "$(cat ${TARGET_DIR}/usr/lib/fipscheck/${2}.hmac)" ]; then
		rm ${1}/.${2}.hmac
	else
		rm ${1}/.${2}.hmac
		die "FIPS Hash mismatch to the certified for ${2}"
	fi
}

if grep -qF "BR2_PACKAGE_LAIRD_OPENSSL_FIPS_BINARIES=y" ${BR2_CONFIG} ||\
   grep -qF "BR2_PACKAGE_LAIRD_OPENSSL_FIPS=y" ${BR2_CONFIG}
then
	hash_check ${BINARIES_DIR} ${IMAGE_NAME}
	hash_check ${TARGET_DIR}/usr/bin fipscheck
	hash_check ${TARGET_DIR}/usr/lib libfipscheck.so.1
	hash_check ${TARGET_DIR}/usr/lib libcrypto.so.1.0.0
fi

if ${SD} ; then
${mkenvimage} -p 0 -s 131072 -o ${BINARIES_DIR}/uboot.env ${BINARIES_DIR}/u-boot-initial-env
else
${mkenvimage} -r -s 131072 -o ${BINARIES_DIR}/uboot.env ${BINARIES_DIR}/u-boot-initial-env
fi

# swupdate will reject an SWU file with sw-description containing hashes unless
# CONFIG_HASH_VERIFY is enabled.  Hashes are required in SWU files if CONFIG_SIGNED_IMAGES
# is set.  Older images did not enable either CONFIG_HASH_VERIFY or CONFIG_SIGNED_IMAGES,
# so remove hashes unless they are required for signed image support.
if ! grep -q 'CONFIG_SIGNED_IMAGES=y' ${BUILD_DIR}/swupdate*/include/config/auto.conf; then
	# Remove sha lines in SWU scripts
	[ ! -f ${BINARIES_DIR}/sw-description ] || \
		sed -i -e "/sha256/d" ${BINARIES_DIR}/sw-description
	sign_method=""
elif grep -q 'CONFIG_SIGALG_CMS=y' ${BUILD_DIR}/swupdate*/include/config/auto.conf; then
	sign_method="cms"
else
	sign_method="rawrsa"
fi

ALL_SWU_FILES="sw-description boot.bin u-boot.itb uboot.env kernel.itb rootfs.bin erase_data.sh"

if ! ${SECURE_BOOT} ; then
	# Generate non-secured artifacts
	echo "# entering ${BINARIES_DIR} for the next command"
	(cd ${BINARIES_DIR} && ${mkimage} -f kernel.its kernel.itb && ${mkimage} -f u-boot.its u-boot.itb) || exit 1
	cat "${BINARIES_DIR}/u-boot-spl-nodtb.bin" "${BINARIES_DIR}/u-boot-spl.dtb" > "${BINARIES_DIR}/u-boot-spl.bin"

	if ${SD} ; then
		${mkimage} -T atmelimage -d ${BINARIES_DIR}/u-boot-spl.bin ${BINARIES_DIR}/boot.bin
	else
		[ -x ${atmel_pmecc_params} ] || \
			die "no atmel_pmecc_params found (uboot has not been built?)"

		# Generate Atmel PMECC boot.bin from SPL
		${mkimage} -T atmelimage -n $(${atmel_pmecc_params}) -d ${BINARIES_DIR}/u-boot-spl.bin ${BINARIES_DIR}/boot.bin
		# Copy rootfs
		ln -rsf ${BINARIES_DIR}/rootfs.squashfs ${BINARIES_DIR}/rootfs.bin
		# Generate SWU
		( cd ${BINARIES_DIR} && \
			echo -e "${ALL_SWU_FILES// /\\n}" |\
			cpio -ovL -H crc > ${BINARIES_DIR}/${BR2_LRD_PRODUCT}.swu)
	fi
else
	# Generate all secured artifacts (NAND, SWU packages)
	"${BOARD_DIR}/../post_image_secure.sh" "${BOARD_DIR}" "${ALL_SWU_FILES}" "${sign_method}" "${SD}"
fi

size_check () {
	[ $(stat -Lc "%s" ${BINARIES_DIR}/${1}) -le $((${2}*128*1024)) ] || \
		{ echo "${1} size exceeded ${2} block limit, failed"; exit 1; }
}

size_check u-boot.itb 7

if [ -n "${VERSION}" ]; then
	RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird-${VERSION}.tar"
else
	RELEASE_FILE="${BINARIES_DIR}/${BR2_LRD_PRODUCT}-laird.tar"
fi

tar -C ${BINARIES_DIR} -chf ${RELEASE_FILE} \
	--owner=root --group=root \
	boot.bin u-boot.itb kernel.itb

if ${SECURE_BOOT} ; then
	tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
		--owner=root --group=root \
		u-boot-spl.dtb u-boot-spl-nodtb.bin u-boot.dtb \
		u-boot-nodtb.bin u-boot.its boot.scr

	tar -C ${HOST_DIR}/usr/bin -rhf ${RELEASE_FILE} \
		--owner=root --group=root \
		fdtget fdtput

	tar -C ${BUILD_DIR}/uboot-custom/tools -rhf ${RELEASE_FILE} \
		--owner=root --group=root \
		mkimage
fi

if ${SD} ; then
	tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
		--owner=root --group=root \
		uboot.env rootfs.tar mksdcard.sh mksdimg.sh
else
	tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
		--owner=root --group=root \
		rootfs.bin ${BR2_LRD_PRODUCT}.swu

	if ${SECURE_BOOT} ; then
		tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
			--owner=root --group=root \
			pmecc.bin uboot.env erase_data.sh sw-description
	fi

	if ${ENCRYPTED_TOOLKIT} ; then
		DTB=$(sed -n 's,.*\"\(.*\.dtb\).*,\1,p' ${BINARIES_DIR}/kernel.its)
		tar -C ${BINARIES_DIR} -rhf ${RELEASE_FILE} \
			--owner=root --group=root \
			u-boot.scr.itb Image.gz "${DTB}" kernel.its rootfs.verity

		tar -C ${HOST_DIR}/usr/bin -rhf ${RELEASE_FILE} \
			--owner=root --group=root \
			fscryptctl
	fi
fi

bzip2 -f ${RELEASE_FILE}

echo "${BR2_LRD_PRODUCT^^} POST IMAGE script: done."
