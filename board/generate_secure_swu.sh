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
openssl=${HOST_DIR}/usr/bin/openssl

[ -x "${openssl}" ] || \
	die "no openssl found (host-openssl has not been built?)"

echo "# entering ${WORKING_DIR} for this script"
cd "${WORKING_DIR}" || exit 1

[ -f sw-description ] && have_swdesc=true || have_swdesc=false

# Backup incoming sw-description* and restore prior to exit
# Caller needs unprocessed versions for further use
${have_swdesc} && cp sw-description sw-description-saved

# Embed component hashes in SWU scripts
for i in ${SWU_FILES/sw-description /}
do
	sha_value=$(sha256sum $i | awk '{print $1}')
	component_sha="@${i}.sha256"
	echo "${i}          ${sha_value}"

	${have_swdesc} && \
		sed -i -e "s/${component_sha}/${sha_value}/g" sw-description

	if [ "${i}" = rootfs.bin ] || [ "${i}" = kernel.itb ]; then
		md5_value=$(md5sum $i | awk '{print $1}')
		component_md5sum="@${i}.md5sum"
		echo "${i}          ${md5_value}"

		${have_swdesc} && \
			sed -i -e "s/${component_md5sum}/${md5_value}/g" sw-description
	fi
done

if [ -n "${SWUPDATE_SIG}" ]; then
	ALL_SWU_FILES="${SWU_FILES/sw-description/sw-description sw-description.sig}"
else
	ALL_SWU_FILES="${SWU_FILES}"
fi
SWU_FILE_STR="${ALL_SWU_FILES// /\\n}"

# Generate SWU
if ${have_swdesc} ; then
	case "${SWUPDATE_SIG}" in
	cms)
		${openssl} cms -sign -in sw-description -out sw-description.sig \
			-signer keys/dev.crt -inkey keys/dev.key -outform DER -nosmimecap -binary
		;;

	rawrsa)
		${openssl} dgst -sha256 -sign keys/dev.key sw-description > sw-description.sig
		;;
	esac

	echo -e "${SWU_FILE_STR}" | cpio -ovL -H crc > "${PRODUCT}.swu"
	rm -f sw-description.sig
fi

${have_swdesc} && mv -f sw-description-saved sw-description

cd - || exit 1

echo "${PRODUCT^^} Generate secure SWU script: done."