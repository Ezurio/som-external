#!/bin/sh
#
# mkrodata.sh - Create read-only factory data image
#
# usage: mkrodata.sh <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>
#
# This script must be run as root!
#
# The optional customer data should be a directory containing anything a customer may require in rodata.
# This provides a way to copy in data living in a custom br2-external.

[ $# -lt 5 ] && echo "usage: mkrodata.sh <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>" && exit 1
[ "$(id -u)" -ne 0 ] && echo "Please run as root" && exit 1

KEY_BIN="${1}"
UPDATE_PUB_CERT="${2}"
REST_SERVER_CERT="${3}"
REST_SERVER_PRIV_KEY="${4}"
REST_SERVER_CERT_CHAIN="${5}"
CUSTOMER_DIR="${6}"

RODATA_MNT_DIR="/mnt/rodata"
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
RODATA_IMG="rodata.img"
RODATA_SQUASHFS="rodata.squashfs"

die() {
  echo "${1}" >&2; exit 1
}

die_with_cleanup() {
  echo "${1}" >&2
  /usr/sbin/dmsetup remove rodata_enc
  rm -f ${RODATA_IMG} ${RODATA_SQUASHFS}
  losetup -d "${LOOP_DEVICE}" || true
  exit 1
}

if [ ! -f "${KEY_BIN}" ] && [ -z "${KEY_BIN}" ] ; then
  die "Missing encryption key"
fi
[ -f "${UPDATE_PUB_CERT}" ] || die "Missing update public key"
[ -f "${REST_SERVER_CERT}" ] || die "Missing REST server certificate"
[ -f "${REST_SERVER_PRIV_KEY}" ] || die "Missing REST server private key"
[ -f "${REST_SERVER_CERT_CHAIN}" ] || die "Missing REST server certificate chain"

#
# Create encrypted directory
#
mkdir -p ${SECRET_DIR} || die "Failed to create ${SECRET_DIR}"

#
# Create and populate REST server certificate and key under encrypted directory
#
mkdir -p ${REST_SERVER_SSL_DIR} || die "Failed to create ${REST_SERVER_SSL_DIR}"
cp "${REST_SERVER_CERT}" ${REST_SERVER_CERT_DEST} || die "Failed to populate REST server certficate"
cp "${REST_SERVER_PRIV_KEY}" ${REST_SERVER_KEY_DEST} || die "Failed to populate REST server key"
cp "${REST_SERVER_CERT_CHAIN}" ${REST_SERVER_CERT_CHAIN_DEST} || die "Failed to populate REST server certificate chain"

#
# Populate REST server provisioning certificates and key under encrypted directory
#
cp "${REST_SERVER_CERT}" ${REST_SERVER_PROVISIONING_CERT_DEST} || die "Failed to populate REST server provisioning certficate"
cp "${REST_SERVER_PRIV_KEY}" ${REST_SERVER_PROVISIONING_KEY_DEST} || die "Failed to populate REST server provisioning key"
cp "${REST_SERVER_CERT_CHAIN}" ${REST_SERVER_PROVISIONING_CERT_CHAIN_DEST} || die "Failed to populate REST server provisioning certificate chain"

#
# Create and populate update public certificate
#
mkdir -p ${UPDATE_CERT_DIR} || die "Failed to create ${UPDATE_CERT_DIR}"
openssl x509 -in "${UPDATE_PUB_CERT}" -pubkey -noout -outform pem -out ${UPDATE_CERT_DEST} || die "Failed to generate update certificate"

#
# Copy in optional customer data
#
if [ -d "${CUSTOMER_DIR}" ];then
  rsync -rlpDWK --no-perms --exclude=.empty  "${CUSTOMER_DIR}" "${RODATA_MNT_DIR}"/
fi

#
# Generate the manifest file
#
[ -f rodata_manifest.txt ] && rm -f rodata_manifest.txt
find ${RODATA_MNT_DIR} -type f -exec md5sum {} \; >> rodata_manifest.txt

#
# Create the SquashFS image
#
mksquashfs ${RODATA_MNT_DIR} ${RODATA_SQUASHFS} || die_with_cleanup "Failed to create SquashFS image"

#
# Create a block image for the read-only data
#
RODATA_SIZE=$(stat -c %s ${RODATA_SQUASHFS})
RODATA_SIZE=$((((RODATA_SIZE / 512) + 2) * 512)) # Round up to the next 512-byte block
RODATA_SIZE=$((RODATA_SIZE / 1024)) # Convert to KiB
fallocate -l ${RODATA_SIZE}KiB ${RODATA_IMG} || die_with_cleanup "Creation of block image failed"
LOOP_DEVICE=$(losetup -f) || die_with_cleanup "Failed to find free loop device"
losetup "${LOOP_DEVICE}" ${RODATA_IMG} || die_with_cleanup "Failed to associate loop device with image"
sync

#
# Setup dm-crypt
#
if [ -f "${KEY_BIN}" ] ; then
  KEY_ASCII_HEX=$(xxd -p < "${KEY_BIN}" | tr -d '\n')
else
  KEY_ASCII_HEX=$(echo "${KEY_BIN}" | xxd -p | tr -d '\n')
fi
/usr/sbin/dmsetup create rodata_enc --table "0 $((RODATA_SIZE * 2)) crypt aes-xts-plain64 ${KEY_ASCII_HEX} 0 ${LOOP_DEVICE} 0 1 sector_size:512" || die_with_cleanup "Failed to create dm-crypt device"

#
# dd the SquashFS image to the dm-crypt device
#
dd if=${RODATA_SQUASHFS} of=/dev/mapper/rodata_enc bs=512 conv=fsync || die_with_cleanup "Failed to dd SquashFS image to dm-crypt device"

#
# Clean up
#
sync
/usr/sbin/dmsetup remove rodata_enc || die_with_cleanup "Failed to remove dm-crypt device"
rm -f ${RODATA_SQUASHFS} || die_with_cleanup "Failed to remove SquashFS image"
losetup -d "${LOOP_DEVICE}" || die_with_cleanup "Failed to detach loop device"
rm -rf ${RODATA_MNT_DIR} || die_with_cleanup "Failed to clean up mount directory"

echo "Successfully created factory data in ${RODATA_IMG}"
