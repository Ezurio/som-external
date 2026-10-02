#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio

# Decrypt the i.MX provisioning archive with ELE, import its PKCS#11 objects,
# copy its optional product data, and mark the device as provisioned.
#
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

set -eu

INPUT_DIR="/usr/share/summit-prov-imx"
PROVISIONED_FLAG="/data/.provisioned"
PROVISIONING_DATA_DIR="/data/prov"
P11_TOOL="/usr/bin/pkcs11-tool --module /usr/lib/libckteec.so.0"
TOKEN_LABEL="summit-keystore"
SO_PIN="1234567890"
PIN="12345"
WORKDIR_TMP=""

# Decryption key and IV, populated by the package build only for builds without
# BR2_SUMMIT_IMX_AHAB. Secure builds leave these empty and decrypt with ELE.
DECRYPT_KEY=""
DECRYPT_IV=""

cleanup() {
    if [ -n "${WORKDIR_TMP}" ]; then
        rm -rf "${WORKDIR_TMP}"
    fi
}
trap cleanup EXIT HUP INT TERM

import_cert() {
    file_basename=$(basename "$1")
    label=${file_basename%.*}

    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "${label}" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "$1" \
        --type cert || {
        echo "Failed to import certificate $1 into token ${TOKEN_LABEL}!"
        return 1
    }

    # Retrieve public key from certificate and import it as a public key object
    openssl x509 -in "$1" -inform DER -pubkey -noout \
        > "${WORKDIR_TMP}/pubkey.pem" || {
        echo "Failed to extract public key from certificate $1!"
        return 1
    }
    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "${label}" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "${WORKDIR_TMP}/pubkey.pem" \
        --type pubkey --usage-sign --usage-derive || {
        echo "Failed to import public key from certificate $1 into token ${TOKEN_LABEL}!"
        return 1
    }
}

import_key() {
    file_basename=$(basename "$1")
    label=${file_basename%.*}

    ${P11_TOOL} \
        --token-label "${TOKEN_LABEL}" \
        --label "${label}" \
        --id "$2" \
        --login \
        --pin "${PIN}" \
        --write-object "$1" \
        --type privkey --usage-sign --usage-derive || {
        echo "Failed to import key $1 into token ${TOKEN_LABEL}!"
        return 1
    }
}

import_certs_and_keys() {
    for directory in "${WORKDIR_TMP}/keystore/"*/; do
        [ -d "${directory}" ] || continue
        object_id=$(basename "${directory}")

        if [ -d "${directory}/cert" ]; then
            find "${directory}/cert" -name "*.der" -type f | \
                while IFS= read -r filename; do
                    import_cert "${filename}" "${object_id}" || exit 1
                done || return 1
        fi

        if [ -d "${directory}/privkey" ]; then
            find "${directory}/privkey" -name "*.der" -type f | \
                while IFS= read -r filename; do
                    import_key "${filename}" "${object_id}" || exit 1
                done || return 1
        fi
    done
}

if [ -f "${PROVISIONED_FLAG}" ]; then
    echo "Device already provisioned. Exiting."
    exit 0
fi

if [ -n "${DECRYPT_KEY}" ]; then
    PAYLOAD="prov-data.tar.gz.aes-cbc"
    ARTIFACTS="${PAYLOAD} SHA256SUMS"
    echo "Non-secure build: decrypting the provisioning archive with the key stored in this image"
else
    PAYLOAD="prov-data.tar.gz.aes-gcm"
    ARTIFACTS="key-exchange.bin oem-ka-public.bin key-import-tlv.bin ${PAYLOAD} SHA256SUMS"
fi

for artifact in ${ARTIFACTS}; do
    if [ ! -f "${INPUT_DIR}/${artifact}" ]; then
        echo "Provisioning artifact ${INPUT_DIR}/${artifact} not found!"
        exit 1
    fi
done

(
    cd "${INPUT_DIR}"
    sha256sum -c SHA256SUMS
) || {
    echo "Provisioning artifact checksum verification failed!"
    exit 1
}

umask 077
WORKDIR_TMP=$(mktemp -d -t summit-prov-imx.XXXXXX)
OUTPUT_FILE="${WORKDIR_TMP}/prov_data.tar.gz"

if [ -n "${DECRYPT_KEY}" ]; then
    openssl enc -d -aes-256-cbc \
        -K "${DECRYPT_KEY}" \
        -iv "${DECRYPT_IV}" \
        -in "${INPUT_DIR}/${PAYLOAD}" \
        -out "${OUTPUT_FILE}" || {
        echo "Failed to decrypt the provisioning archive!"
        exit 1
    }
else
    /usr/sbin/summit-prov-imx \
        "${INPUT_DIR}/key-exchange.bin" \
        "${INPUT_DIR}/oem-ka-public.bin" \
        "${INPUT_DIR}/key-import-tlv.bin" \
        "${INPUT_DIR}/${PAYLOAD}" \
        "${OUTPUT_FILE}" || {
        echo "Failed to authenticate and decrypt the provisioning archive!"
        exit 1
    }
fi

# Extract the certificates and private keys from decrypted keystore tar.gz
tar -xzpf "${OUTPUT_FILE}" -C "${WORKDIR_TMP}" || {
    echo "Failed to extract the decrypted provisioning archive!"
    exit 1
}

rm -f "${OUTPUT_FILE}"

if [ ! -d "${WORKDIR_TMP}/keystore" ]; then
    echo "The decrypted provisioning archive has no keystore directory!"
    exit 1
fi

${P11_TOOL} --init-token --label "${TOKEN_LABEL}" --so-pin "${SO_PIN}" || {
    echo "Failed to initialize token ${TOKEN_LABEL}!"
    exit 1
}
${P11_TOOL} --label "${TOKEN_LABEL}" --login --so-pin "${SO_PIN}" \
    --init-pin --pin "${PIN}" || {
    echo "Failed to set user PIN for token ${TOKEN_LABEL}!"
    exit 1
}

import_certs_and_keys || {
    echo "Failed to import certificates and keys into token ${TOKEN_LABEL}!"
    exit 1
}

if [ -d "${WORKDIR_TMP}/data" ]; then
    mkdir -p "${PROVISIONING_DATA_DIR}"
    cp -a "${WORKDIR_TMP}/data/." "${PROVISIONING_DATA_DIR}/" || {
        echo "Failed to copy provisioning data to ${PROVISIONING_DATA_DIR}!"
        exit 1
    }
fi

rm -rf "${WORKDIR_TMP}"
WORKDIR_TMP=""

touch "${PROVISIONED_FLAG}.tmp"
sync
mv "${PROVISIONED_FLAG}.tmp" "${PROVISIONED_FLAG}"
sync
echo "Provisioning completed successfully."
