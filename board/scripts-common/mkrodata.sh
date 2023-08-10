#!/bin/sh
#
# mkrodata.sh - Create read-only factory data image
#
# usage: mkrodata.sh <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>
#
# This script requires the modified 'fscryptctl' binary (from the build artifacts)
# to be located in the current directory.
#
# This script must be run as root!
#
# The optional customer data should be a directory containing anything a customer may require in rodata.
# This provides a way to copy in data living in a custom br2-external.

[ $# -lt 5 ] && echo "usage: mkrodata.sh <fscrypt_key> <update_pub_cert> <rest_server_cert> <rest_server_priv_key> <rest_server_certificate_chain> <optional customer data>" && exit 1
[ $(id -u) -ne 0 ] && echo "Please run as root" && exit 1

KEY_BIN="${1}"
UPDATE_PUB_CERT="${2}"
REST_SERVER_CERT="${3}"
REST_SERVER_PRIV_KEY="${4}"
REST_SERVER_CERT_CHAIN="${5}"
CUSTOMER_DIR="${6}"

FSCRYPTCTL="./fscryptctl"

LOOP_DEVICE=$(losetup -f)
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
RODATA_SIZE=256
EXT4_BLOCK_SIZE=4096
KEY_DESC="ffffffffffffffff"

exit_on_error() {
  echo $1
  umount -fq ${RODATA_MNT_DIR} || true
  rm -f ${RODATA_IMG}
  exit 1
}

[ -f "${KEY_BIN}" ] || exit_on_error "Missing encryption key"
[ -f "${UPDATE_PUB_CERT}" ] || exit_on_error "Missing update public key"
[ -f "${REST_SERVER_CERT}" ] || exit_on_error "Missing REST server certificate"
[ -f "${REST_SERVER_PRIV_KEY}" ] || exit_on_error "Missing REST server private key"
[ -f "${REST_SERVER_CERT_CHAIN}" ] || exit_on_error "Missing REST server certificate chain"
[ -x "${FSCRYPTCTL}" ] || exit_on_error "Missing local fscryptctl"

#
# Prepare mount point
#
rm -rf ${RODATA_MNT_DIR} || exit_on_error "Directory removal for ${RODATA_DIR} failed"
mkdir -p ${RODATA_MNT_DIR} || exit_on_error "Directory Creation for ${RODATA_DIR} failed"

#
# Create filesystem on loop image
#
fallocate -l ${RODATA_SIZE}KiB ${RODATA_IMG} || exit_on_error "Creation of block image failed"
mkfs.ext4 -O encrypt -O ^has_journal -b ${EXT4_BLOCK_SIZE} ${RODATA_IMG} || exit_on_error "EXT4 formatting failed"

mount -o loop=${LOOP_DEVICE} ${RODATA_IMG} ${RODATA_MNT_DIR} || exit_on_error "Mounting ${LOOP_DEVICE} failed"

#
# Create encrypted directory and apply policy (must be done on empty directory)
#
cat ${KEY_BIN} | ${FSCRYPTCTL} insert_key --desc=${KEY_DESC}
mkdir -p ${SECRET_DIR} || exit_on_error "Failed to create ${SECRET_DIR}"
${FSCRYPTCTL} set_policy ${KEY_DESC} ${SECRET_DIR} || exit_on_error "Failed to apply encryption policy"

#
# Create and populate REST server certificate and key under encrypted directory
#
mkdir -p ${REST_SERVER_SSL_DIR} || exit_on_error "Failed to create ${REST_SERVER_SSL_DIR}"
cp ${REST_SERVER_CERT} ${REST_SERVER_CERT_DEST} || exit_on_error "Failed to populate REST server certficate"
cp ${REST_SERVER_PRIV_KEY} ${REST_SERVER_KEY_DEST} || exit_on_error "Failed to populate REST server key"
cp ${REST_SERVER_CERT_CHAIN} ${REST_SERVER_CERT_CHAIN_DEST} || exit_on_error "Failed to populate REST server certificate chain"

#
# Populate WebLCM provisioning certificates and key under encrypted directory
#
cp ${REST_SERVER_CERT} ${REST_SERVER_PROVISIONING_CERT_DEST} || exit_on_error "Failed to populate REST server provisioning certficate"
cp ${REST_SERVER_PRIV_KEY} ${REST_SERVER_PROVISIONING_KEY_DEST} || exit_on_error "Failed to populate REST server provisioning key"
cp ${REST_SERVER_CERT_CHAIN} ${REST_SERVER_PROVISIONING_CERT_CHAIN_DEST} || exit_on_error "Failed to populate REST server provisioning certificate chain"

#
# Create and populate update public certificate
#
mkdir -p ${UPDATE_CERT_DIR} || exit_on_error "Failed to create ${UPDATE_CERT_DIR}"
cp ${UPDATE_PUB_CERT} ${UPDATE_CERT_DEST} || exit_on_error "Failed to populate update certificate"

#
# Copy in optional customer data
#
if [ -d "${CUSTOMER_DIR}" ];then
  rsync -rlpDWK --no-perms --exclude=.empty  "${CUSTOMER_DIR}" "${RODATA_MNT_DIR}"/
fi

#
# Clean up
#
sync
umount ${RODATA_MNT_DIR}
keyctl unlink $(keyctl search @s logon fscrypt:ffffffffffffffff)

echo "Successfully created factory data in ${RODATA_IMG}"
