#!/bin/sh
#
# mkrodata.sh - Create read-only factory data image
#
# usage: mkrodata.sh <working_dir> <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>
#
# The optional customer data should be a directory containing anything a customer may require in rodata.
# This provides a way to copy in data living in a custom br2-external.
#
# If the optional customer data contains secret/rest-server/ssl/, that subtree is treated as
# authoritative and will be copied as-is into rodata. Otherwise the default rest_server_cert,
# rest_server_priv_key, and rest_server_certificate_chain arguments are used to seed both the
# runtime and provisioning SSL files.

[ $# -lt 6 ] && echo "usage: mkrodata.sh <working_dir> <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>" && exit 1

WORKING_DIR="${1:-.}"
KEY_BIN="${2}"
UPDATE_PUB_CERT="${3}"
REST_SERVER_CERT="${4}"
REST_SERVER_PRIV_KEY="${5}"
REST_SERVER_CERT_CHAIN="${6}"
CUSTOMER_DIR="${7}"
CUSTOMER_SSL_DIR="${CUSTOMER_DIR%/}/secret/rest-server/ssl"

RODATA_MNT_DIR="${WORKING_DIR}/mnt/rodata"
SECRET_DIR="${RODATA_MNT_DIR}/secret"
PUBLIC_DIR="${RODATA_MNT_DIR}/public"
REST_SERVER_SSL_DIR="${SECRET_DIR}/rest-server/ssl"
REST_SERVER_CERT_DEST="${REST_SERVER_SSL_DIR}/server.crt"
REST_SERVER_KEY_DEST="${REST_SERVER_SSL_DIR}/server.key"
REST_SERVER_CERT_CHAIN_DEST="${REST_SERVER_SSL_DIR}/ca.crt"
REST_SERVER_PROVISIONING_CERT_DEST="${REST_SERVER_SSL_DIR}/provisioning.crt"
REST_SERVER_PROVISIONING_KEY_DEST="${REST_SERVER_SSL_DIR}/provisioning.key"
REST_SERVER_PROVISIONING_CERT_CHAIN_DEST="${REST_SERVER_SSL_DIR}/provisioning.ca.crt"
UPDATE_CERT_DIR="${PUBLIC_DIR}/ssl/misc"
UPDATE_CERT_DEST="${UPDATE_CERT_DIR}/update.pem"
RODATA_IMG="${WORKING_DIR}/rodata.img"
RODATA_SQUASHFS="${WORKING_DIR}/rodata.squashfs"

die() {
  echo "${1}" >&2; exit 1
}

populate_default_rest_server_ssl() {
  [ -f "${REST_SERVER_CERT}" ] || die "Missing REST server certificate"
  [ -f "${REST_SERVER_PRIV_KEY}" ] || die "Missing REST server private key"
  [ -f "${REST_SERVER_CERT_CHAIN}" ] || die "Missing REST server certificate chain"

  mkdir -p "${REST_SERVER_SSL_DIR}" || die "Failed to create ${REST_SERVER_SSL_DIR}"
  cp "${REST_SERVER_CERT}" "${REST_SERVER_CERT_DEST}" || die "Failed to populate REST server certificate"
  cp "${REST_SERVER_PRIV_KEY}" "${REST_SERVER_KEY_DEST}" || die "Failed to populate REST server key"
  cp "${REST_SERVER_CERT_CHAIN}" "${REST_SERVER_CERT_CHAIN_DEST}" || die "Failed to populate REST server certificate chain"

  cp "${REST_SERVER_CERT}" "${REST_SERVER_PROVISIONING_CERT_DEST}" || die "Failed to populate REST server provisioning certificate"
  cp "${REST_SERVER_PRIV_KEY}" "${REST_SERVER_PROVISIONING_KEY_DEST}" || die "Failed to populate REST server provisioning key"
  cp "${REST_SERVER_CERT_CHAIN}" "${REST_SERVER_PROVISIONING_CERT_CHAIN_DEST}" || die "Failed to populate REST server provisioning certificate chain"
}

populate_customer_rest_server_ssl() {
  mkdir -p "${REST_SERVER_SSL_DIR}" || die "Failed to create ${REST_SERVER_SSL_DIR}"
  rsync -rlpDWK --no-perms --exclude=.empty "${CUSTOMER_SSL_DIR}/" "${REST_SERVER_SSL_DIR}/" || \
    die "Failed to populate customer REST server SSL directory"
}

#
# Extracts all certificates from the input cert/bundle and returns fingerprints and validity period
#
cert_info() {
  CERT_FILE="$1"
  csplit -f "${WORKING_DIR}"/tmpcert_ -q "$CERT_FILE" '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null || true
  CERT_NUM=0
  for tmpcert in "${WORKING_DIR}"/tmpcert_*; do
    if [ -s "$tmpcert" ] && grep -q -- "-----BEGIN CERTIFICATE-----" "$tmpcert" 2>/dev/null; then
      echo "cert_info $1_$CERT_NUM"
      openssl x509 -in "$tmpcert" -noout -fingerprint -sha1 2>/dev/null
      openssl x509 -in "$tmpcert" -noout -fingerprint -sha256 2>/dev/null
      openssl x509 -in "$tmpcert" -noout -fingerprint -md5 -dates 2>/dev/null
      CERT_NUM=$((CERT_NUM + 1))
    fi
  done
  rm -f "${WORKING_DIR}"/tmpcert_*
}

if [ -z "${KEY_BIN}" ] ; then
  die "Missing encryption key"
fi
# Select how to pass the key to dmcrypt_image:
# - existing file  → pass as raw binary with -K (no conversion needed)
# - literal string → convert to hex inline with --key-hex (no temp file)
if [ -f "${KEY_BIN}" ] ; then
  KEY_ARG="-K ${KEY_BIN}"
else
  KEY_ARG="--key-hex $(printf '%s' "${KEY_BIN}" | xxd -p | tr -d '\n')"
fi

[ -f "${UPDATE_PUB_CERT}" ] || die "Missing update public key"

#
# Create encrypted directory
#
mkdir -p "${SECRET_DIR}" || die "Failed to create ${SECRET_DIR}"

#
# Populate REST server SSL data under the encrypted directory. A customer-provided
# secret/rest-server/ssl tree overrides the stock defaults entirely.
#
if [ -n "${CUSTOMER_DIR}" ] && [ -d "${CUSTOMER_SSL_DIR}" ]; then
  populate_customer_rest_server_ssl
else
  populate_default_rest_server_ssl
fi

#
# Create and populate update public certificate
#
mkdir -p "${UPDATE_CERT_DIR}" || die "Failed to create ${UPDATE_CERT_DIR}"
openssl x509 -in "${UPDATE_PUB_CERT}" -pubkey -noout -outform pem -out "${UPDATE_CERT_DEST}" || die "Failed to generate update certificate"

#
# Copy in optional customer data
#
if [ -d "${CUSTOMER_DIR}" ];then
  rsync -rlpDWK --no-perms --exclude=.empty --exclude=/secret/rest-server/ssl "${CUSTOMER_DIR}" "${RODATA_MNT_DIR}"/
fi

#
# Generate the manifest file
#
[ -f "${WORKING_DIR}/rodata_manifest.txt" ] && rm -f "${WORKING_DIR}/rodata_manifest.txt"
find "${RODATA_MNT_DIR}" -type f -exec md5sum "{}" \; >> "${WORKING_DIR}/rodata_manifest.txt"
find "${RODATA_MNT_DIR}" -type f -name "*.crt" | while read -r cert_file; do
  cert_info "$cert_file" >> "${WORKING_DIR}/rodata_manifest.txt"
done

#
# Create the SquashFS image
#
mksquashfs "${RODATA_MNT_DIR}" "${RODATA_SQUASHFS}" || die_with_cleanup "Failed to create SquashFS image"

#
# Create a block image for the read-only data
#
# shellcheck disable=SC2086
dmcrypt_image \
  --input  "${RODATA_SQUASHFS}" \
  --output "${RODATA_IMG}"      \
  ${KEY_ARG}                    \
  || die "Failed to create encrypted image"

rm -rf "${RODATA_MNT_DIR}" "${RODATA_SQUASHFS}"

echo "Successfully created factory data in ${RODATA_IMG}"
