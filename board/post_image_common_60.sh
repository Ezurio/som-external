#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

BUILD_TYPE="${2}"

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE script: starting..."

# Determine if we are building SD card image
case "${BUILD_TYPE}" in
*sd) SD=true  ;;
  *) SD=false ;;
esac

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT=y" "${BR2_CONFIG}" \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false

grep -qF "BR2_SUMMIT_SECURE_BOOT=y" "${BR2_CONFIG}" \
	&& SECURE_BOOT=true || SECURE_BOOT=false

UBOOT_VER=$(make -C "${BASE_DIR}" uboot-show-version)

# Tooling checks
mkimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkimage
atmel_pmecc_params=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/atmel_pmecc_params
mkenvimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkenvimage
fipshmac=${HOST_DIR}/bin/fipshmac

die() { echo "$@" >&2; exit 1; }

[ -x "${mkimage}" ] || \
	die "No mkimage found (uboot has not been built?)"
[ -x "${mkenvimage}" ] || \
	die "No mkenvimage found (uboot has not been built?)"

(cd "${BINARIES_DIR}" && "${mkimage}" -f u-boot.scr.its u-boot.scr.itb) || exit 1

IMAGE_NAME=Image

if grep -qF '"Image.gz"' "${BINARIES_DIR}/kernel.its"; then
	gzip -9kfn "${BINARIES_DIR}/Image"
	IMAGE_NAME+=.gz
elif grep -qF '"Image.lzo"' "${BINARIES_DIR}/kernel.its"; then
	lzop -9on "${BINARIES_DIR}/Image.lzo" "${BINARIES_DIR}/Image"
	IMAGE_NAME+=.lzo
elif grep -qF '"Image.lzma"' "${BINARIES_DIR}/kernel.its"; then
	lzma -9kf "${BINARIES_DIR}/Image"
	IMAGE_NAME+=.lzma
elif grep -qF '"Image.zstd"' "${BINARIES_DIR}/kernel.its"; then
	zstd -19 -kf "${BINARIES_DIR}/Image" -o "${BINARIES_DIR}/Image.zstd"
	IMAGE_NAME+=.zstd
fi

hash_check() {
	${fipshmac} "${1}/${2}"
	if [ "$(cat "${1}/.${2}.hmac")" = "$(cat "${TARGET_DIR}/usr/lib/fipscheck/${2}.hmac")" ]; then
		rm "${1}/.${2}.hmac"
	else
		rm "${1}/.${2}.hmac"
		die "FIPS Hash mismatch to the certified for ${2}"
	fi
}

if grep -qF -e "BR2_PACKAGE_SUMMITSSL_FIPS_BINARIES=y" -e "BR2_PACKAGE_SUMMIT_OPENSSL_FIPS=y" "${BR2_CONFIG}"
then
	hash_check "${BINARIES_DIR}" "${IMAGE_NAME}"
	hash_check "${TARGET_DIR}/usr/bin" fipscheck
	hash_check "${TARGET_DIR}/usr/lib" libfipscheck.so.1
	hash_check "${TARGET_DIR}/usr/lib" libcrypto.so.1.0.0
elif grep -qF -e "BR2_PACKAGE_SUMMIT_OPENSSL_FIPS_PROVIDER=y" -e "BR2_PACKAGE_LIBOPENSSL_ENABLE_FIPS=y" "${BR2_CONFIG}"
then
	hash_check "${BINARIES_DIR}" "${IMAGE_NAME}"
	hash_check "${TARGET_DIR}/usr/bin" fipscheck
	hash_check "${TARGET_DIR}/usr/lib" libfipscheck.so.1
	hash_check "${TARGET_DIR}/usr/lib/ossl-modules" fips.so
fi

# Generate U-Boot environment
if ${SD} ; then
	${mkenvimage} -p 0 -s 131072 -o "${BINARIES_DIR}/uboot.env" "${BINARIES_DIR}/u-boot-initial-env"
else
	${mkenvimage} -r -s 131072 -o "${BINARIES_DIR}/uboot.env" "${BINARIES_DIR}/u-boot-initial-env"
	if grep -qF boot1.bin "${BINARIES_DIR}/sw-description" ; then
		echo "keyrev=1" | cat - "${BINARIES_DIR}/u-boot-initial-env" | sort > "${BINARIES_DIR}/u-boot1-initial-env"
		${mkenvimage} -r -s 131072 -o "${BINARIES_DIR}/uboot1.env" "${BINARIES_DIR}/u-boot1-initial-env"
	fi
fi

# Copy rootfs
ln -sf rootfs.squashfs "${BINARIES_DIR}/rootfs.bin"

# Generate images
if ! ${SECURE_BOOT} ; then
	# Generate non-secured artifacts
	(cd "${BINARIES_DIR}" && ${mkimage} -f kernel.its kernel.itb && ${mkimage} -f u-boot.its u-boot.itb) || exit 1

	cat "${BINARIES_DIR}/u-boot-spl-nodtb.bin" "${BINARIES_DIR}/u-boot-spl.dtb" > "${BINARIES_DIR}/u-boot-spl.bin"
	if ${SD} ; then
		${mkimage} -T atmelimage -d "${BINARIES_DIR}/u-boot-spl.bin" "${BINARIES_DIR}/boot.bin"
	else
		[ -x "${atmel_pmecc_params}" ] || \
			die "no atmel_pmecc_params found (uboot has not been built?)"

		# Generate Atmel PMECC boot.bin from SPL
		${mkimage} -T atmelimage -n "$(${atmel_pmecc_params})" -d "${BINARIES_DIR}/u-boot-spl.bin" "${BINARIES_DIR}/boot.bin"
	fi
else
	# Generate all secured artifacts
	UBOOT_VER=${UBOOT_VER} "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_secure.sh" "${SD}"
fi

if ! ${SD} ; then
	SWU_FILES="sw-description boot.bin u-boot.itb uboot.env kernel.itb rootfs.bin erase_data.sh"

	# Support Secure boot key transition
	if grep -qF boot1.bin "${BINARIES_DIR}/sw-description" ; then
		SWU_FILES="${SWU_FILES/boot.bin/boot.bin boot1.bin}"
		SWU_FILES="${SWU_FILES/uboot.env/uboot.env uboot1.env}"
		cp -af "${BINARIES_DIR}/boot.bin" "${BINARIES_DIR}/boot1.bin"
	fi

	# Call script to generate secure SWU
	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/generate_swu.sh" "${SWU_FILES}"
fi

if ! ${SD} ; then
	size_check () {
		[ "$(stat -Lc "%s" "${BINARIES_DIR}/${1}")" -le $((${2}*128*1024)) ] || \
			{ echo "${1} size exceeded ${2} block limit, failed"; exit 1; }
	}

	size_check u-boot.itb 7
fi

RELEASE_FILE="${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}${BR2_SUMMIT_BUILD_SUFFIX}-summit-${BR2_SUMMIT_BUILD_VERSION}.tar"

tar -C "${BINARIES_DIR}" -chf "${RELEASE_FILE}" \
	--owner=root --group=root \
	boot.bin u-boot.itb kernel.itb rootfs.bin

if ${SECURE_BOOT} ; then
	tar -rhf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		u-boot-spl.dtb u-boot-spl-nodtb.bin u-boot.dtb \
		u-boot-nodtb.bin u-boot.its boot.scr \
		-C "${HOST_DIR}/usr/bin" \
		fdtget fdtput \
		-C "${BUILD_DIR}/uboot-custom/tools" \
		mkimage
fi

if ${ENCRYPTED_TOOLKIT} ; then
	DTB=$(sed -n 's,.*\"\(.*\.dtb\).*,\1,p' "${BINARIES_DIR}/kernel.its")
	tar -rhf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		u-boot.scr.itb Image.gz "${DTB}" kernel.its rootfs.verity \
		-C "${HOST_DIR}/usr/bin" \
		fscryptctl
fi

if ${SD} ; then
	tar -rhf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		uboot.env mksdcard.sh mksdimg.sh
else
	tar -rhf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		"${BR2_SUMMIT_PRODUCT}.swu"

	if ${SECURE_BOOT} ; then
		tar -rhf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			pmecc.bin uboot.env erase_data.sh sw-description
	fi
fi

# Move back the OpenJDK 'modules' dependency to the target directory
# after creating the image and dependency tarball. Also, add the
# dependency tarball to the release archive
if grep -qF "BR2_SUMMIT_OPENJDK_GGV2=y" "${BR2_CONFIG}"
then
	# Delete the symlink and move back the original 'modules' file
	rm -f "${TARGET_DIR}/usr/lib/jvm/lib/modules"
	mv "${BINARIES_DIR}/jdk/lib/modules" "${TARGET_DIR}/usr/lib/jvm/lib/"

	# Delete the temporary 'jdk' directory
	rm -rf "${BINARIES_DIR}/jdk"

	# Add the dependency tarball to the release archive
	OPENJDK_TARBALL_FILE=${BR2_SUMMIT_PRODUCT}${BR2_SUMMIT_BUILD_SUFFIX}-summit-openjdk.tar.gz
	tar -C "${BINARIES_DIR}" -rhf "${RELEASE_FILE}" \
		--owner=root --group=root \
		"${OPENJDK_TARBALL_FILE}"
fi

bzip2 -f "${RELEASE_FILE}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE script: done."
