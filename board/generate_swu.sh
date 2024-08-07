#!/bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio
#
# generate_swu.sh
#
# Generate SWU artifacts
#
# Required Inputs
#	$SWU_FILES		Files to store in .swu
#
# Artifacts generated in $WORKING_DIR:
#	${PRODUCT}.swu		SWU (signed)

# enable tracing and exit on errors
set -x -e

SWU_FILES="${1}"

echo "${BR2_SUMMIT_PRODUCT^^} Generate SWU script: starting..."

die() { echo "$@" >&2; exit 1; }

[ -r "${BINARIES_DIR}/sw-description" ] ||
	die "no sw-description found in ${BINARIES_DIR}"

# Backup incoming sw-description* and restore prior to exit
# Caller needs unprocessed versions for further use
cp -af "${BINARIES_DIR}"/sw-description "${BINARIES_DIR}"/sw-description-saved

# swupdate will reject an SWU file with sw-description containing hashes unless
# CONFIG_HASH_VERIFY is enabled.  Hashes are required in SWU files if CONFIG_SIGNED_IMAGES
# is set.  Older images did not enable either CONFIG_HASH_VERIFY or CONFIG_SIGNED_IMAGES,
# so remove hashes unless they are required for signed image support.
if grep -qF 'CONFIG_SIGNED_IMAGES=y' "${BUILD_DIR}"/swupdate*/include/config/auto.conf; then
	# Secure tooling checks
	openssl=$(command -v openssl)
	[ -x "${openssl}" ] || \
		die "no openssl found"

	# Embed component hashes in SWU scripts
	for i in ${SWU_FILES/sw-description /} ; do
		sha_value=$(sha256sum "${BINARIES_DIR}/${i}" | awk '{print $1}')
		echo "${i}          ${sha_value}"
		sed -i -e "s/@${i}.sha256/${sha_value}/g" "${BINARIES_DIR}"/sw-description
	done

	if grep -qF ".md5sum" "${BINARIES_DIR}"/sw-description ; then
		for i in rootfs.bin kernel.itb ; do
			[ -f "${BINARIES_DIR}/${i}" ] || continue
			md5_value=$(md5sum "${BINARIES_DIR}/${i}" | awk '{print $1}')
			echo "${i}          ${md5_value}"
			sed -i -e "s/@${i}.md5sum/${md5_value}/g" "${BINARIES_DIR}"/sw-description
		done
	fi

	SWU_FILES=${SWU_FILES/sw-description/sw-description sw-description.sig}

	# Create keys if not present
	if [ ! -f "${BINARIES_DIR}"/keys/dev.key ]; then
		mkdir -p "${BINARIES_DIR}"/keys
		${openssl} genrsa -out "${BINARIES_DIR}"/keys/dev.key 2048
		${openssl} req -batch -new -x509 -key "${BINARIES_DIR}"/keys/dev.key -out "${BINARIES_DIR}"/keys/dev.crt
	fi

	if grep -qF 'CONFIG_SIGALG_CMS=y' "${BUILD_DIR}"/swupdate*/include/config/auto.conf; then
		${openssl} cms -sign -in "${BINARIES_DIR}"/sw-description -out "${BINARIES_DIR}"/sw-description.sig \
			-signer "${BINARIES_DIR}"/keys/dev.crt -inkey "${BINARIES_DIR}"/keys/dev.key \
			-outform DER -nosmimecap -binary
	else
		${openssl} dgst -sha256 -sign "${BINARIES_DIR}"/keys/dev.key -out "${BINARIES_DIR}"/sw-description.sig \
			"${BINARIES_DIR}"/sw-description
	fi
else
	sed -i -e "/sha256/d" "${BINARIES_DIR}"/sw-description
fi

# Generate SWU
cd "${BINARIES_DIR}"
echo -e "${SWU_FILES// /\\n}" | cpio -ovL -H crc > "${BR2_SUMMIT_PRODUCT}.swu"
cd -

rm -f "${BINARIES_DIR}"/sw-description.sig
mv -f "${BINARIES_DIR}"/sw-description-saved "${BINARIES_DIR}"/sw-description


echo "${BR2_SUMMIT_PRODUCT^^} Generate SWU script: done."
