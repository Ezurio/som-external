#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

export BUILD_TYPE="${2}"

# enable tracing and exit on errors
set -x -e

if [ -z "${BR2_SUMMIT_PRODUCT}" ]; then
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"
	export BR2_SUMMIT_PRODUCT
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON script: starting..."

# Determine if encrypted image being built
grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT=y" "${BR2_CONFIG}" \
	&& ENCRYPTED_TOOLKIT=true || ENCRYPTED_TOOLKIT=false
export ENCRYPTED_TOOLKIT

grep -qF "BR2_SUMMIT_SECURE_BOOT=y" "${BR2_CONFIG}" \
	&& SECURE_BOOT=true || SECURE_BOOT=false
export SECURE_BOOT

die() { echo "$@" >&2; exit 1; }

# Generate all build artifacts
"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/post_image_secure.sh"

if [ -f "${BINARIES_DIR}/sw-description" ]; then
	# Call script to generate secure SWU
	"${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/generate_swu.sh"
fi

RELEASE_FILE="${BINARIES_DIR}/${BR2_SUMMIT_PRODUCT}${BR2_SUMMIT_BUILD_SUFFIX}-summit-${BR2_SUMMIT_BUILD_VERSION}.tar"

# Determine if we are building SD card image
case "${BUILD_TYPE}" in
som60*|wb50n*|ig60*)
	case "${BUILD_TYPE}" in
	*sd)
		tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			boot.bin u-boot.itb uboot.env kernel.itb rootfs.bin \
			mksdcard.sh mksdimg.sh
		;;
	*)
		tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			"${BR2_SUMMIT_PRODUCT}.swu"

		if ${SECURE_BOOT} ; then
			tar -rhSf "${RELEASE_FILE}" --owner=root --group=root \
				-C "${BINARIES_DIR}" \
				boot.bin u-boot.itb uboot.env kernel.itb rootfs.bin \
				pmecc.bin erase_data.sh sw-description
		fi
		;;
	esac

	if ${SECURE_BOOT} ; then
		tar -rhSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			u-boot-spl.dtb u-boot-spl-nodtb.bin u-boot.dtb \
			u-boot-nodtb.bin u-boot.its boot.scr \
			-C "${HOST_DIR}/usr/bin" \
			fdtget fdtput \
			-C "${BUILD_DIR}/uboot-custom/tools" \
			mkimage
	fi

	if ${ENCRYPTED_TOOLKIT} || [ "${BUILD_TYPE}" = ig60 ]; then
		DTB=$(sed -rn 's,.*\("(.*\.dtb).*,\1,p' "${BINARIES_DIR}/kernel.its")
		tar -rhSf "${RELEASE_FILE}" --owner=root --group=root \
			-C "${BINARIES_DIR}" \
			Image.gz "${DTB}" kernel.its rootfs.verity \
			-C "${HOST_DIR}/usr/bin" \
			fscryptctl
	fi
	;;

imx8*|*am62*)
	tar -chSf "${RELEASE_FILE}" --owner=root --group=root \
		-C "${BINARIES_DIR}" \
		"${BR2_SUMMIT_PRODUCT}.swu" mksdcard.sh mksdimg.sh
	;;
esac

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
	tar -C "${BINARIES_DIR}" -rhSf "${RELEASE_FILE}" \
		--owner=root --group=root \
		"${OPENJDK_TARBALL_FILE}"
fi

bzip2 -f "${RELEASE_FILE}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE COMMON script: done."
