#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio
#
# summit-key-provider: check the secure-boot signing keys and generate the
# Cloud HSM key wrappers.
#
# On Carbon and Nitrogen (SUMMIT_KEY_PROVIDER_PLATFORM set) local keys are used
# in place from SIG_KEY_PATH.  For Cloud HSM builds this script writes PKCS#11
# PEM wrappers, and the FIT certificate, to WRAP_DIR, which SIG_KEY_PATH
# points at.  Certificates and other support files stay in SIG_SUPPORT_PATH.
#
# Other boards get a copy of SIG_KEY_PATH in KEYS_DIR.
#
# The HSM backend (AWS KMS, GCP Cloud KMS, Azure Key Vault, ...) is selected
# via CLOUD_HSM_BACKEND (default: aws-kms) and only affects how a key
# identifier is mapped to a PKCS#11 token label.
#
# Invoked from the host-summit-key-provider build step
# (HOST_SUMMIT_KEY_PROVIDER_BUILD_CMDS in summit-key-provider.mk):
#   summit-key-provider.sh materialize
#
# May also be invoked directly for debugging:
#   summit-key-provider.sh gen-wrapper <key_id> <output_path>
#   summit-key-provider.sh gen-cert    <key_path> <cert_path> <common_name>
#
# Required environment (passed by summit-key-provider.mk):
#   HOST_DIR, KEYS_DIR, WRAP_DIR, SIG_KEY_PATH, SIG_SUPPORT_PATH,
#   CLOUD_HSM_SIGNING, CLOUD_HSM_BACKEND, CLOUD_HSM_REQUIRED_ROLES,
#   HSM_KEY_ID, HSM_FIT_KEY_ID, HSM_UPDATE_KEY_ID,
#   SUMMIT_KEY_PROVIDER_PLATFORM
#   OPENSSL_CONF, AWS_KMS_PKCS11_CONFIG (HSM only)

die() { echo "summit-key-provider: $*" >&2; exit 1; }

# ─── Backend: token label extraction ───────────────────────────────────────────
# Each backend maps its key identifier (ARN, resource name, URI, ...) to a
# PKCS#11 token label.  CK_TOKEN_INFO.label is 32 bytes max.
hsm_token_label() {
    case "${CLOUD_HSM_BACKEND:-aws-kms}" in
        aws-kms)
            # AWS KMS ARN format: arn:aws:kms:<region>:<account>:key/<uuid>
            # Token label = first 32 chars of the key UUID.
            echo "$1" | sed 's|.*/||' | cut -c1-32
            ;;
        # gcp-kms)
        #     echo "$1" | ... ;;
        # azure-kv)
        #     echo "$1" | ... ;;
        *)
            die "Unknown CLOUD_HSM_BACKEND: ${CLOUD_HSM_BACKEND}"
            ;;
    esac
}

# ─── Generic PKCS#11 operations ───────────────────────────────────────────────

# Generate a PKCS#11 PEM wrapper for a token label via uri2pem.py.
# Usage: hsm_gen_wrapper <token_label> <output_path>
hsm_gen_wrapper() {
    python3 "${HOST_DIR}/opt/pkcs11-provider/uri2pem.py" \
        --bypass --verify --out "$2" \
        "pkcs11:token=$1;type=private"
}

# Convenience: generate a wrapper given a backend key identifier.
# Usage: hsm_gen_wrapper_id <key_id> <output_path>
hsm_gen_wrapper_id() {
    hsm_gen_wrapper "$(hsm_token_label "$1")" "$2"
}

# Generate a self-signed X.509 certificate from a PEM wrapper key.
# mkimage requires a certificate (not a raw public key) for FIT verification.
# Usage: hsm_gen_cert <key_path> <cert_path> <common_name>
hsm_gen_cert() {
    openssl req -new -x509 \
        -key "$1" \
        -out "$2" \
        -days 3650 -nodes \
        -subj "/CN=$3"
}

# Public key of a private key (file or PKCS#11 wrapper) or a certificate, as
# text: the PKCS#11 provider emits PKCS#1 PEM while certificates give SPKI.
key_pub_text() {
    openssl pkey -in "$1" -pubout 2>/dev/null | \
        openssl pkey -pubin -text_pub -noout 2>/dev/null
}
crt_pub_text() {
    openssl x509 -in "$1" -pubkey -noout 2>/dev/null | \
        openssl pkey -pubin -text_pub -noout 2>/dev/null
}

# Devices pin update_signing.crt (SWUpdate CMS), so it must be supplied and
# match the update signing key.
check_update_cert() {
    _crt="${SIG_SUPPORT_PATH}/update_signing.crt"
    _key="${SIG_KEY_PATH}/update_signing.key"
    [ -f "${_crt}" ] || \
        die "update_signing.crt not found in SIG_SUPPORT_PATH (${SIG_SUPPORT_PATH});" \
            "devices pin this certificate"
    _crt_pub=$(crt_pub_text "${_crt}") || _crt_pub=""
    _key_pub=$(key_pub_text "${_key}") || _key_pub=""
    if [ -z "${_key_pub}" ] || [ "${_key_pub}" != "${_crt_pub}" ]; then
        die "${_crt} does not match ${_key}"
    fi
}

# ─── Carbon and Nitrogen ───────────────────────────────────────────────────────
# Generate the Cloud HSM wrappers in WRAP_DIR, then check the keys that
# SIG_KEY_PATH points at.
hsm_wrap() {
    hsm_gen_wrapper_id "$1" "${WRAP_DIR}/$2" || \
        die "HSM wrapper failed for the $3 key; check the Cloud HSM credentials"
}

do_platform() {
    : "${SIG_KEY_PATH:?SIG_KEY_PATH not set}"
    : "${SIG_SUPPORT_PATH:?SIG_SUPPORT_PATH not set}"

    [ -d "${SIG_SUPPORT_PATH}" ] || \
        die "SIG_SUPPORT_PATH not found: ${SIG_SUPPORT_PATH}"

    if [ -n "${CLOUD_HSM_SIGNING}" ]; then
        : "${WRAP_DIR:?WRAP_DIR not set}"
        rm -rf "${WRAP_DIR}"
        mkdir -p "${WRAP_DIR}"
        # mkimage needs a certificate next to the FIT key.
        hsm_wrap "${HSM_FIT_KEY_ID}" dev.key FIT
        hsm_gen_cert "${WRAP_DIR}/dev.key" "${WRAP_DIR}/dev.crt" dev
        case " ${CLOUD_HSM_REQUIRED_ROLES} " in
        *" KEY "*)
            hsm_wrap "${HSM_KEY_ID}" smpk.key SMPK
            hsm_gen_cert "${WRAP_DIR}/smpk.key" "${WRAP_DIR}/smpk.crt" smpk ;;
        esac
        hsm_wrap "${HSM_UPDATE_KEY_ID}" update_signing.key update
    else
        [ -z "${WRAP_DIR}" ] || rm -rf "${WRAP_DIR}"
    fi

    [ -f "${SIG_KEY_PATH}/dev.key" ] || \
        die "dev.key not found in SIG_KEY_PATH (${SIG_KEY_PATH})"
    check_update_cert
}

# ─── Other boards ──────────────────────────────────────────────────────────────
# Copy SIG_KEY_PATH into KEYS_DIR.
do_copy() {
    : "${KEYS_DIR:?KEYS_DIR not set}"
    : "${SIG_KEY_PATH:?SIG_KEY_PATH not set}"

    [ -d "${SIG_KEY_PATH}" ] || \
        die "SIG_KEY_PATH not found: ${SIG_KEY_PATH}"

    rm -rf "${KEYS_DIR}"
    mkdir -p "${KEYS_DIR}"
    cp -a "${SIG_KEY_PATH}/." "${KEYS_DIR}/"

    [ -f "${KEYS_DIR}/dev.key" ] || \
        die "No dev.key in ${SIG_KEY_PATH} (needed for signing)"
}

# ─── Dispatch ───────────────────────────────────────────────────────────────────
set -e
[ -n "${HOST_DIR}" ] || die "HOST_DIR not set"
# Ensure host-built tools (openssl, python3, ...) are found before system ones.
PATH="${HOST_DIR}/bin:${HOST_DIR}/sbin:${PATH}"
export PATH

cmd="${1:?Usage: $0 <materialize|gen-wrapper|gen-cert> ...}"
shift || true
case "${cmd}" in
    materialize)
        if [ -n "${SUMMIT_KEY_PROVIDER_PLATFORM}" ]; then
            do_platform
        else
            do_copy
        fi ;;
    gen-wrapper)
        [ $# -ge 2 ] || die "Usage: $0 gen-wrapper <key_id> <output_path>"
        hsm_gen_wrapper_id "$1" "$2" ;;
    gen-cert)
        [ $# -ge 3 ] || die "Usage: $0 gen-cert <key_path> <cert_path> <cn>"
        hsm_gen_cert "$@" ;;
    *)
        die "Unknown command: ${cmd}" ;;
esac
