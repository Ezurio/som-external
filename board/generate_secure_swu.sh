#!/bin/bash

#
# generate_secure_swu.sh
#
# Generate Secure SWU artifacts
#
# Required Inputs
#
#	$PRODUCT		Name of .swu output file
#	$WORKING_DIR		Path that contains files required by .swu generation
#	$SWU_FILES		Files to store in .swu
#	$SWUPDATE_SIG		swupdate signiture file
#
# Secured artifacts generated in $WORKING_DIR:
#	${PRODUCT}.swu		SWU (signed)

# enable tracing and exit on errors
set -x -e

PRODUCT="${1}"
WORKING_DIR="${2}"
SWU_FILES="${3}"
SWUPDATE_SIG="${4}"

echo "${PRODUCT^^} Generate Secure SWU script: starting..."

# Secure tooling checks
openssl=$(which openssl)
[ -x "${openssl}" ] || \
	die "no openssl found"

[ -r "${WORKING_DIR}/sw-description" ] ||
	die "no sw-description found in ${WORKING_DIR}"

cd "${WORKING_DIR}"

# Backup incoming sw-description* and restore prior to exit
# Caller needs unprocessed versions for further use
cp -af sw-description sw-description-saved

# Embed component hashes in SWU scripts
for i in ${SWU_FILES/sw-description /} ; do
	sha_value=$(sha256sum "${i}" | awk '{print $1}')
	echo "${i}          ${sha_value}"
	sed -i -e "s/@${i}.sha256/${sha_value}/g" sw-description
done

if grep -qF ".md5sum" sw-description ; then
	for i in rootfs.bin kernel.itb ; do
		[ -f "${i}" ] || continue
		md5_value=$(md5sum "${i}" | awk '{print $1}')
		echo "${i}          ${md5_value}"
		sed -i -e "s/@${i}.md5sum/${md5_value}/g" sw-description
	done
fi

[ -z "${SWUPDATE_SIG}" ] || \
	SWU_FILES="${SWU_FILES/sw-description/sw-description sw-description.sig}"

# Generate SWU
case "${SWUPDATE_SIG}" in
cms)
	${openssl} cms -sign -in sw-description -out sw-description.sig \
		-signer keys/dev.crt -inkey keys/dev.key \
		-outform DER -nosmimecap -binary
	;;

rawrsa)
	${openssl} dgst -sha256 -sign keys/dev.key -out sw-description.sig \
		sw-description
	;;
esac

echo -e "${SWU_FILES// /\\n}" | cpio -ovL -H crc > "${PRODUCT}.swu"

rm -f sw-description.sig
mv -f sw-description-saved sw-description

cd -

echo "${PRODUCT^^} Generate secure SWU script: done."
