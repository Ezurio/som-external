#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio
#
# summit-key-provider: assemble the secure-boot keys directory for any source.
#
# This script is the single materialization point for signing key material.
# It produces a self-contained KEYS_DIR (and, for HAB platforms, a staged
# SIG_DATA_PATH) that downstream build steps consume without needing to know
# whether keys come from local files or a cloud HSM (PKCS#11).
#
# For LOCAL builds it simply copies the platform key material into KEYS_DIR.
# For Cloud HSM builds it additionally overlays PKCS#11 PEM wrappers (and,
# where required, self-signed certificates) in place of the private keys.
#
# The HSM backend (AWS KMS, GCP Cloud KMS, Azure Key Vault, ...) is selected
# via CLOUD_HSM_BACKEND (default: aws-kms) and only affects how a key
# identifier is mapped to a PKCS#11 token label.
#
# Invoked from post_build_common.sh (see summit-key-provider.mk):
#   summit-key-provider.sh materialize
# Invoked from the U-Boot pre-build hook for HAB (i.MX8M) builds:
#   summit-key-provider.sh stage-hab
#
# May also be invoked directly for debugging:
#   summit-key-provider.sh gen-wrapper <key_id> <output_path>
#   summit-key-provider.sh gen-cert    <key_path> <cert_path> <common_name>
#
# Required environment (exported/passed by summit-key-provider.mk):
#   HOST_DIR, KEYS_DIR, LOCAL_KEYS_DIR
#   CLOUD_HSM_SIGNING, CLOUD_HSM_BACKEND,
#   HSM_KEY_ID, HSM_CSF_KEY_ID, HSM_IMG_KEY_ID, HSM_FIT_KEY_ID,
#   SUMMIT_KEY_PROVIDER_PLATFORM
#   OPENSSL_CONF (HSM only)
# For HAB staging (stage-hab): SIG_DATA_PATH, SIG_DATA_PATH_ORIG, CSF_KEY,
#   IMG_KEY, HSM_CSF_KEY_ID, HSM_IMG_KEY_ID, HSM_FIT_KEY_ID

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

# ─── HAB (i.MX8M) SIG_DATA_PATH staging ────────────────────────────────────────
# Copy crts/ from the original PKI tree and generate PKCS#11 wrappers for the
# CSF/IMG private keys.  CST locates private keys by swapping crts/ -> keys/
# and _crt.pem -> _key.pem.  The FIT key ("dev") is also staged.
hsm_stage_hab() {
    _orig="${SIG_DATA_PATH_ORIG:?SIG_DATA_PATH_ORIG not set}"
    _stage="${SIG_DATA_PATH:?SIG_DATA_PATH not set}"

    rm -rf "${_stage}"
    mkdir -p "${_stage}/keys"
    cp -a "${_orig}/crts" "${_stage}/crts"

    _csf_base=$(basename "${CSF_KEY}" | sed 's/_crt\.pem$/_key.pem/')
    hsm_gen_wrapper_id "${HSM_CSF_KEY_ID}" "${_stage}/keys/${_csf_base}" || \
        die "HSM wrapper failed for CSF key (HSM_CSF_KEY_ID=${HSM_CSF_KEY_ID})"

    _img_base=$(basename "${IMG_KEY}" | sed 's/_crt\.pem$/_key.pem/')
    hsm_gen_wrapper_id "${HSM_IMG_KEY_ID}" "${_stage}/keys/${_img_base}" || \
        die "HSM wrapper failed for IMG key (HSM_IMG_KEY_ID=${HSM_IMG_KEY_ID})"

    # CST reads the passphrase from keys/key_pass.txt — for PKCS#11 wrappers
    # the passphrase is unused, but the file must exist.
    printf '\n\n' > "${_stage}/keys/key_pass.txt"

    # FIT signing key "dev" (hardcoded as the key-name-hint in kernel.its,
    # see UBOOT_SIGN_KEYNAME in post_build_common.sh).
    _fit_id="${HSM_FIT_KEY_ID:-${HSM_KEY_ID}}"
    if [ -n "${_fit_id}" ]; then
        hsm_gen_wrapper_id "${_fit_id}" "${_stage}/keys/dev.key" || \
            die "HSM wrapper failed for FIT key"
        hsm_gen_cert "${_stage}/keys/dev.key" "${_stage}/keys/dev.crt" dev
    elif [ -f "${_orig}/keys/dev.key" ]; then
        cp -a "${_orig}/keys/dev.key" "${_stage}/keys/dev.key"
        [ ! -f "${_orig}/keys/dev.crt" ] || \
            cp -a "${_orig}/keys/dev.crt" "${_stage}/keys/dev.crt"
    fi
}

# ─── Materialize ───────────────────────────────────────────────────────────────
# Assemble KEYS_DIR from the local platform key material, then overlay HSM
# PKCS#11 wrappers where a cloud key is configured.
do_materialize() {
    : "${KEYS_DIR:?KEYS_DIR not set}"
    : "${LOCAL_KEYS_DIR:?LOCAL_KEYS_DIR not set}"

    [ -d "${LOCAL_KEYS_DIR}" ] || \
        die "Local keys directory not found: ${LOCAL_KEYS_DIR}"

    # Fresh copy of the platform key material (provisioning data, local dev
    # signing keys, filesystem-encryption keys, secure-mode ciphers, ...).
    rm -rf "${KEYS_DIR}"
    mkdir -p "${KEYS_DIR}"
    cp -a "${LOCAL_KEYS_DIR}/." "${KEYS_DIR}/"

    if [ -z "${CLOUD_HSM_SIGNING}" ]; then
        # Local build: the copied dev.key/dev.crt are authoritative.
        [ -f "${KEYS_DIR}/dev.key" ] || \
            die "No dev.key in ${LOCAL_KEYS_DIR} (needed for signing)"
        return 0
    fi

    # ── Cloud HSM overlays ──
    # FIT signing key "dev": replace with a PKCS#11 wrapper + self-signed cert.
    # The copied dev.key/dev.crt may be symlinks (e.g. carbon: dev.* -> smpk.*);
    # remove them first so the wrapper/cert are written as regular files and do
    # not clobber the symlink target.
    _fit_id="${HSM_FIT_KEY_ID:-${HSM_KEY_ID}}"
    if [ -n "${_fit_id}" ]; then
        rm -f "${KEYS_DIR}/dev.key" "${KEYS_DIR}/dev.crt"
        hsm_gen_wrapper_id "${_fit_id}" "${KEYS_DIR}/dev.key" || \
            die "HSM wrapper failed for FIT signing key"
        hsm_gen_cert "${KEYS_DIR}/dev.key" "${KEYS_DIR}/dev.crt" dev
    fi

    # SMPK (AM6xx provisioning): replace with a PKCS#11 wrapper.  Remove first
    # in case dev.key was a symlink to smpk.key in the source tree.
    if [ "${SUMMIT_KEY_PROVIDER_PLATFORM}" = am6 ] && [ -n "${HSM_KEY_ID}" ]; then
        rm -f "${KEYS_DIR}/smpk.key"
        hsm_gen_wrapper_id "${HSM_KEY_ID}" "${KEYS_DIR}/smpk.key" || \
            die "HSM wrapper failed for SMPK key"
    fi
}

# ─── Dispatch ───────────────────────────────────────────────────────────────────
set -e
[ -n "${HOST_DIR}" ] || die "HOST_DIR not set"
# Ensure host-built tools (openssl, python3, ...) are found before system ones.
PATH="${HOST_DIR}/bin:${HOST_DIR}/sbin:${PATH}"
export PATH

cmd="${1:?Usage: $0 <materialize|stage-hab|gen-wrapper|gen-cert> ...}"
shift || true
case "${cmd}" in
    materialize)
        do_materialize ;;
    stage-hab)
        hsm_stage_hab ;;
    gen-wrapper)
        [ $# -ge 2 ] || die "Usage: $0 gen-wrapper <key_id> <output_path>"
        hsm_gen_wrapper_id "$1" "$2" ;;
    gen-cert)
        [ $# -ge 3 ] || die "Usage: $0 gen-cert <key_path> <cert_path> <cn>"
        hsm_gen_cert "$@" ;;
    *)
        die "Unknown command: ${cmd}" ;;
esac
