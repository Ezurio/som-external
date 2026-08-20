#! /bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2025 Ezurio

# This script provisions keys and certificates into the OP-TEE secure storage using
# the pkcs11-tool utility and also copies provisioning data files to /data/prov directory.
#
# The prov_data.tar.gz is expected to have the following structure:
#
# prov_data.tar.gz
# ├── keystore
# │   ├── 01
# │   │   ├── cert
# │   │   │   └── cert-1.der
# │   │   └── privkey
# │   │       └── key-1.der
# │   └── 02
# │       ├── cert
# │       │   └── cert-2.der
# │       └── privkey
# │           └── key-2.der
# └── data
#     ├── file-1.txt
#     └── ...
#
# Here, '01' and '02' are the ID value used to import the keys and certificates. Files under the
# 'cert' subdirectory are certificates to be imported, and files under the 'privkey' subdirectory
# are private keys to be imported.

set -e

SUMMIT_PROV_MODULE="summit_prov"
INPUT_FILE="/boot/prov_data.tar.gz_sign_enc.bin"
WORKDIR_TMP=$(mktemp -d -t import-keys.XXXXXX)
OUTPUT_FILE="${WORKDIR_TMP}/prov_data.tar.gz"
P11_TOOL="/usr/bin/pkcs11-tool --module /usr/lib/libckteec.so.0"
TOKEN_LABEL="summit-keystore"
SO_PIN="1234567890"
PIN="12345"
PROVISIONED_FLAG="/data/.provisioned"
PROVISIONING_DATA_DIR="/data/prov"

# Optional decryption key/IV, only used and populated for non-secure builds
DECRYPT_KEY=""
DECRYPT_IV=""

#shellcheck disable=SC2329
exit_on_error() {
    rm -rf "${WORKDIR_TMP}"
}
trap exit_on_error EXIT

import_cert() {
    file_basename=$(basename "$1")
    label=${file_basename%.*}

    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "$label" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "$1" \
        --type cert || {
        echo "Failed to import certificate $1 into token ${TOKEN_LABEL}!"
        exit 1
    }

    # Retrieve public key from certificate and import it as a public key object
    openssl x509 -in "$1" -inform DER -pubkey -noout > "${WORKDIR_TMP}/pubkey.pem" || {
        echo "Failed to extract public key from certificate $1!"
        exit 1
    }
    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "$label" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "${WORKDIR_TMP}/pubkey.pem" \
        --type pubkey --usage-sign --usage-derive || {
        echo "Failed to import public key from certificate $1 into token ${TOKEN_LABEL}!"
        exit 1
    }
}

import_key() {
    file_basename=$(basename "$1")
    label=${file_basename%.*}

    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "$label" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "$1" \
        --type privkey --usage-sign --usage-derive || {
        echo "Failed to import key $1 into token ${TOKEN_LABEL}!"
        exit 1
    }
}

import_certs_and_keys() {
    for dir in "${WORKDIR_TMP}/keystore/"*/; do
        [ -d "$dir" ] || continue
        id=$(basename "$dir")

        if [ -d "${dir}/cert/" ] ; then
            find "${dir}/cert/" -name "*.der" -type f | while read -r filename; do
                import_cert "$filename" "$id" || exit 1
            done
        fi

        if [ -d "${dir}/privkey/" ] ; then
            find "${dir}/privkey/" -name "*.der" -type f | while read -r filename; do
                import_key "$filename" "$id" || exit 1
            done
        fi
    done
}

if [ -f "${PROVISIONED_FLAG}" ]; then
    echo "Device already provisioned. Exiting."
    exit 0
fi

if [ ! -f "${INPUT_FILE}" ]; then
    echo "Input file ${INPUT_FILE} not found!"
    exit 1
fi

# Decrypt the input file
use_ti_sci=1
if [ -n "${DECRYPT_KEY}" ]; then
    use_ti_sci=0

    # Import decryption key to kernel keyring
    printf "%s" "${DECRYPT_KEY}" | keyctl padd -x user summit_prov_decrypt_key @s > /dev/null || {
        echo "Failed to add decryption key to kernel keyring!"
        exit 1
    }

    # Import decryption IV to kernel keyring
    printf "%s" "${DECRYPT_IV}" | keyctl padd -x user summit_prov_decrypt_iv @s > /dev/null || {
        echo "Failed to add decryption IV to kernel keyring!"
        exit 1
    }
fi

/usr/sbin/modprobe "${SUMMIT_PROV_MODULE}" input_file="${INPUT_FILE}" output_file="${OUTPUT_FILE}" use_ti_sci=${use_ti_sci} || {
    echo "Failed to load module ${SUMMIT_PROV_MODULE} for decryption!"
    exit 1
}

if [ ! -f "${OUTPUT_FILE}" ]; then
    echo "Decrypted output file ${OUTPUT_FILE} not found!"
    exit 1
fi

# Extract the certificates and private keys from decrypted keystore tar.gz
tar -xzpf "${OUTPUT_FILE}" -C "${WORKDIR_TMP}" || {
    echo "Failed to extract the decrypted keystore!"
    exit 1
}

rm -rf "${OUTPUT_FILE}"

if [ -n "$(find "${WORKDIR_TMP}/data/" -maxdepth 1 -type f -print -quit 2>/dev/null)" ]; then
    mkdir -p "${PROVISIONING_DATA_DIR}"
    cp -ar "${WORKDIR_TMP}/data/." "${PROVISIONING_DATA_DIR}/" || {
        echo "Failed to copy provisioning data to ${PROVISIONING_DATA_DIR}!"
        exit 1
    }
fi

# Configure OP-TEE PKCS#11 token
${P11_TOOL} --init-token --label "${TOKEN_LABEL}" --so-pin "${SO_PIN}" || {
    echo "Failed to initialize token ${TOKEN_LABEL}!"
    exit 1
}
${P11_TOOL} --label "${TOKEN_LABEL}" --login --so-pin "${SO_PIN}" --init-pin --pin "${PIN}" || {
    echo "Failed to set user PIN for token ${TOKEN_LABEL}!"
    exit 1
}

import_certs_and_keys || {
    echo "Failed to import certificates and keys into token ${TOKEN_LABEL}!"
    exit 1
}

rm -rf "${INPUT_FILE}" "${WORKDIR_TMP}"

# Mark device as provisioned
mkdir -p /data
touch "${PROVISIONED_FLAG}"
sync
echo "Provisioning completed successfully."
