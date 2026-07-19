#!/bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio
#
# generate_swu.sh
#
# Generate SWU artifacts
#
# Artifacts generated in $WORKING_DIR:
#	${PRODUCT}.swu		SWU (signed)

# enable tracing and exit on errors
set -x -e

echo "${BR2_SUMMIT_PRODUCT^^} Generate SWU script: starting..."

cd "${BINARIES_DIR}"

die() { echo "$@" >&2; cd -; exit 1; }

[ -r "sw-description" ] ||
	die "no sw-description found in ${BINARIES_DIR}"

# Set default version if not provided
[ -n "${VERSION}" ] || VERSION=255.255.255.255

# Replace @@VAR@@ with environment variables
while read -r tok ; do
	var=${tok//@@/}
	[ -n "${!var}" ] || die "Missing value for ${var}"
	sed -i "s/${tok}/${!var}/g" sw-description
done < <(grep -oP '@@.*?@@' sw-description | sort -u)

# Backup incoming sw-description* and restore prior to exit
# Caller needs unprocessed versions for further use
cp -af sw-description sw-description-saved

# Embed component values in SWU scripts
while read -r token ; do
	[ -n "${token}" ] || continue

	if [[ ${token} =~ ^\$swupdate_get_([^(]+)\(([^)]*)\)$ ]]; then
		op=${BASH_REMATCH[1]}
		file=${BASH_REMATCH[2]}
	else
		die "failed to parse SWUpdate token ${token}"
	fi

	case "${op}" in
		size)
			value=$(stat -Lc '%s' "${file}") || die "failed to get file size for ${file}"
			;;
		*)
			read -r value _ < <("${op}sum" "${file}") || \
				die "failed to compute ${op} for ${file}"
			;;
	esac
	echo "${file}          ${value}"
	sed -i "s|${token}|${value}|g" sw-description
done < <(grep -oP '\$swupdate_get_[^(]+\([^)]*\)' sw-description | sort -u)

# Extract SWU files from sw-description
SWU_FILES=$(
{
	sed -rn '/complete:/ {:loop n; s/.*filename = "([^"]+).*/\1/p; b loop}' sw-description
	sed -rn 's/.*filename = "([^"]+).*/\1/p' sw-description
} | awk '!seen[$0]++'
)

[ -n "${SWUPDATE_VER}" ] || \
	SWUPDATE_VER=$(make -j1 -s --no-print-directory -C "${BASE_DIR}" swupdate-show-version | sed '/^make\[/d')

SWUPDATE_CONF=${BUILD_DIR}/swupdate-${SWUPDATE_VER}/include/config/auto.conf
nl=$'\n'

# swupdate will reject an SWU file with sw-description containing hashes unless
# CONFIG_HASH_VERIFY is enabled.  Hashes are required in SWU files if CONFIG_SIGNED_IMAGES
# is set.  Older images did not enable either CONFIG_HASH_VERIFY or CONFIG_SIGNED_IMAGES,
# so remove hashes unless they are required for signed image support.
if grep -qF 'CONFIG_SIGNED_IMAGES=y' "${SWUPDATE_CONF}"; then
	# Secure tooling checks
	openssl=$(command -v openssl)
	[ -x "${openssl}" ] || \
		die "no openssl found"

	# Create keys if not present
	if [ ! -f keys/update_signing.key ]; then
		mkdir -p keys
		${openssl} genrsa -out keys/update_signing.key 2048
		${openssl} req -batch -new -x509 -key keys/update_signing.key -out keys/update_signing.crt
	fi

	if grep -qF 'CONFIG_SIGALG_CMS=y' "${SWUPDATE_CONF}"; then
		${openssl} cms -sign -in sw-description -out sw-description.sig \
			-signer keys/update_signing.crt -inkey keys/update_signing.key \
			-outform DER -nosmimecap -binary
	else
		${openssl} dgst -sha256 -sign keys/update_signing.key -out sw-description.sig \
			sw-description
	fi

	SWU_FILES="sw-description${nl}sw-description.sig${nl}${SWU_FILES}"
else
	SWU_FILES="sw-description${nl}${SWU_FILES}"
fi

# Generate SWU
cpio -ovL -H crc > "${BR2_SUMMIT_PRODUCT}.swu" <<< "${SWU_FILES}"

rm -f sw-description.sig
mv -f sw-description-saved sw-description

cd -

echo "${BR2_SUMMIT_PRODUCT^^} Generate SWU script: done."
