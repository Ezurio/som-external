#!/bin/sh

die() { echo "$@" >&2; exit 1; } 

case "${BUILD_TYPE}" in
    *am6*)
        if ! grep -qF "BR2_PACKAGE_SUMMIT_PROV=y" "${BR2_CONFIG}"; then
            touch "${BINARIES_DIR}/prov_data.tar.zst_sign_enc.bin"
            exit 0
        fi

        # Assume SMEK and SMPK are in the keys directory
        smek_path="${KEYS_DIR}/smek.key"
        [ -f "${smek_path}" ] || \
            die "No SMEK key found in the keys directory"
        smpk_path="${KEYS_DIR}/smpk.key"
        [ -f "${smpk_path}" ] || \
            die "No SMPK key found in the keys directory"
        prov_data_path="${KEYS_DIR}/prov_data"
        [ -d "${prov_data_path}" ] || \
            die "No provisioning data directory found in the keys directory"
        keystore_source_path="${prov_data_path}/keystore"
        [ -d "${keystore_source_path}" ] || \
            die "No keystore directory found in the prov_data directory"

        # Create prov_data.tar.zst
        tar -C "${prov_data_path}" -cf - . | zstd -fo "${BINARIES_DIR}/prov_data.tar.zst"

        if [ -n "${SECURE_TARGET_BUILD}" ]; then
            # Secure target build, sign and encrypt the provisioning data using SMPK and SMEK
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/carbon/scripts/gen_core_x509_cert.sh" \
                -b "${BINARIES_DIR}/prov_data.tar.zst" \
                -k "${smpk_path}" \
                -a 2 \
                -n \
                -y ENCRYPT \
                -e "${smek_path}" \
                -o "${BINARIES_DIR}/cert_prov_data.tar.zst.bin"
            cat "${BINARIES_DIR}/cert_prov_data.tar.zst.bin" "${BINARIES_DIR}/prov_data.tar.zst-ENC" > "${BINARIES_DIR}/prov_data.tar.zst_sign_enc.bin"
            shred -zn 0 "${BINARIES_DIR}/cert_prov_data.tar.zst.bin" "${BINARIES_DIR}/prov_data.tar.zst-ENC"
        else
            # If not a secure target build, encrypt the prov_data.tar.zst using SMEK and inject the SMEK
            # and IV into the summit-prov.sh script using sed (for decryption during provisioning)
            KEY_SIZE=$(stat -c%s "${smek_path}")
            KEY=$(xxd -p -c "${KEY_SIZE}" "${smek_path}")
            IV=$(openssl rand -hex 16)
            openssl enc -aes-256-cbc -in "${BINARIES_DIR}/prov_data.tar.zst" -out "${BINARIES_DIR}/prov_data.tar.zst_sign_enc.bin" -K "${KEY}" -iv "${IV}"

            # Update the decryption key and IV variables for summit-prov.sh using sed
            sed -i -r \
                -e "s/^(DECRYPT_KEY=).*/\1\"${KEY}\"/" \
                -e "s/^(DECRYPT_IV=).*/\1\"${IV}\"/" \
                "${TARGET_DIR}/usr/sbin/summit-prov.sh"
        fi
        shred -zn 0 "${BINARIES_DIR}/prov_data.tar.zst"

        # Verify the encrypted provisioning data file is not greater than 1MB
        if [ "$(stat -c%s "${BINARIES_DIR}/prov_data.tar.zst_sign_enc.bin")" -gt 1048576 ]; then
            die "Generated encrypted provisioning data file exceeds 1MB size limit"
        fi
        ;;
    *)
        ;;
esac
