#!/bin/sh
#
# mkrodata-default.sh - Create read-only factory data image
#
# usage: mkrodata-default.sh <som-external dir> <optional customer data>
#
# This script requires the modified 'fscryptctl' binary (from the build artifacts)
# to be located in the current directory.
#
# This script must be run as root!
#
# The optional customer data should be a directory containing anything a customer may require in rodata.
# This provides a way to copy in data living in a custom br2-external.

[ $# -lt 1 ] && echo "usage: mkrodata-default.sh <som-external dir> <optional customer data>" && exit 1

REST_SERVER_CERTS_DIR=${1}/board/configs-common/keys/rest-server
BOARD_DIR=${1}/board/configs-common/keys
CUSTOMER_DIR=${2}

./mkrodata.sh "${BOARD_DIR}"/key-fs.bin "${BOARD_DIR}"/dev.pem "${REST_SERVER_CERTS_DIR}"/server.crt "${REST_SERVER_CERTS_DIR}"/server.key "${REST_SERVER_CERTS_DIR}"/ca.crt "${CUSTOMER_DIR}"

mv -f rodata.img ${1}/package/lrd/lrd-encrypted-storage-toolkit/rootfs/etc/rodata
