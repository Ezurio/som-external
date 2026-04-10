#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2025 Ezurio

# enable tracing and exit on errors
set -x -e -o pipefail

[ -n "${BR2_SUMMIT_PRODUCT}" ] || \
    BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

echo "${BR2_SUMMIT_PRODUCT^^} POST FAKE ROOT COMMON script: starting..."

BUILD_TYPE="${2}"

die() { echo "$@" >&2; exit 1; }

generate_custom_encrypted_filesystem() {
    customer_data_dir=""
    update_signing_cert="${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/update_signing.crt"
    if [ -n "${SECURE_TARGET_BUILD}" ]; then
        # Secure target build, use the custom key
        encrypted_filesystem_key="${KEYS_DIR}/encrypted_filesystem_key.bin"
        [ -f "${encrypted_filesystem_key}" ] || \
            die "Encrypted filesystem key not found"

        update_signing_cert="${KEYS_DIR}/update_signing.crt"
    else
        # Not a secure target build, use the default filesystem encryption key
        encrypted_filesystem_key="${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/key-fs.bin"
        [ -f "${encrypted_filesystem_key}" ] || \
            die "Encrypted filesystem key not found"
    fi

    # Check if a customer data directory is provided
    if [ -n "${ENCRYPTED_FILESYSTEM_DATA_DIR}" ] ; then
        [ -d "${ENCRYPTED_FILESYSTEM_DATA_DIR}" ] || \
            die "Encrypted filesystem data directory not found"
        customer_data_dir="${ENCRYPTED_FILESYSTEM_DATA_DIR}/"
    fi

    RODATA_DIR="${TARGET_DIR}/etc/rodata"
    mkdir -p "${RODATA_DIR}" || die "Failed to create ${RODATA_DIR}"

    # Generate the encrypted filesystem
    "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/mkrodata.sh" \
        "${RODATA_DIR}" \
        "${encrypted_filesystem_key}" \
        "${update_signing_cert}" \
        "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.crt" \
        "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.key" \
        "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/ca.crt" \
        "${customer_data_dir}"

    [ -f "${RODATA_DIR}/rodata.img" ] || \
        die "Failed to generate encrypted filesystem"

    [ -f "${RODATA_DIR}/rodata_manifest.txt" ] || \
        die "Failed to generate encrypted filesystem manifest"
}

write_encrypted_filesystem_key() {
    fdtput=${HOST_DIR}/bin/fdtput
    [ -x "${fdtput}" ] || \
        die "No fdtput found (uboot has not been built?)"
    fdtget=${HOST_DIR}/bin/fdtget
    [ -x "${fdtget}" ] || \
        die "No fdtget found (uboot has not been built?)"

    encrypted_filesystem_key_path="${KEYS_DIR}/encrypted_filesystem_key.bin"
    [ -f "${encrypted_filesystem_key_path}" ] || \
        die "No encrypted filesystem key found in the keys directory"

    set +x
    key_name="summit,fs-key"
    if ! ${fdtget} "${BINARIES_DIR}/u-boot.dtb" /encryption "${key_name}" > /dev/null; then
        # Property "summit,fs-key" does not exist, use the legacy name
        key_name="laird,fs-key"
    fi

    encrypted_filesystem_key=$(hexdump -v -e '1/1 "%02X"' "${encrypted_filesystem_key_path}" | \
        sed 's/.\{8\}/& /g' | \
        sed 's/[[:space:]]*$//')
    # shellcheck disable=SC2086
    ${fdtput} -p -t x "${BINARIES_DIR}/u-boot.dtb" \
        /encryption \
        "${key_name}" \
        ${encrypted_filesystem_key} || \
            die "Failed to write encrypted filesystem key to U-Boot device tree"
    set -x
}

create_secure_boot_encryption_key() {
    # Check if the Secure SAM-BA Cipher Tool is available
    samba_cipher_tool_dir="${HOST_DIR}/opt/secure-sam-ba-cipher"
    [ -f "${samba_cipher_tool_dir}/sam_gen_keypayload.py" ] || \
        die "No Secure SAM-BA Cipher Tool found - is the host-secure-sam-ba-cipher package enabled?"

    license_path="${KEYS_DIR}/license_sama5d3_Prod.txt"
    [ -f "${license_path}" ] || \
        die "No license file found in the keys directory"

    license_key="${KEYS_DIR}/license_private_Prod.pem"
    [ -f "${license_key}" ] || \
        die "No license key found in the keys directory"

    license_passcode="${KEYS_DIR}/license_passcode.txt"
    [ -f "${license_passcode}" ] || \
        die "No license passcode found in the keys directory"

    secure_boot_encryption_key="${KEYS_DIR}/secure_boot_encryption_key.txt"
    [ -f "${secure_boot_encryption_key}" ] || \
        die "No secure boot encryption key found in the keys directory"

    set +x
    # Generate the customer key config file
    customer_key_config="${KEYS_DIR}/customer_key_config.yaml"
    cat > "${customer_key_config}" << EOF
chip_type: sama5d3x
image_type: secure
security:
    key_cust: hfil:${KEYS_DIR}/secure_boot_encryption_key.txt
EOF

    "${HOST_DIR}/bin/python3" "${samba_cipher_tool_dir}/sam_gen_keypayload.py" \
        -l "${license_path}" -k "${customer_key_config}" \
        -o "${BINARIES_DIR}/customer_key.cip" -pk "${license_key}" \
        -pp "$(sed -e s/pass://g < "${license_passcode}")"
    set -x

    # Verify the customer key files were created successfully
    if [ -f "${BINARIES_DIR}/customer_key_aes_sama5d3x.cip" ]; then
        mv "${BINARIES_DIR}/customer_key_aes_sama5d3x.cip" "${BINARIES_DIR}/customer_key_sama5d3x.cip"
    else
        die "Failed to generate customer key"
    fi
    if [ -f "${BINARIES_DIR}/customer_key_aes_sama5d3x_nk.cip" ]; then
        mv "${BINARIES_DIR}/customer_key_aes_sama5d3x_nk.cip" "${BINARIES_DIR}/customer_key_sama5d3x_nk.cip"
    else
        die "Failed to generate customer key"
    fi
}

get_secure_mode_command() {
    # Transfer the necessary secure mode command files to the output directory
    set_secure_mode_file_1="secure_mode_sama5d3x.cip"
    [ -f "${KEYS_DIR}/${set_secure_mode_file_1}" ] || \
        die "No set secure mode file found in the keys directory"
    
    set_secure_mode_file_2="secure_mode_sama5d3x_nk.cip"
    [ -f "${KEYS_DIR}/${set_secure_mode_file_2}" ] || \
        die "No set secure mode nk file found in the keys directory"
    
    cp "${KEYS_DIR}/${set_secure_mode_file_1}" "${BINARIES_DIR}/${set_secure_mode_file_1}" || \
        die "Failed to copy set secure mode file"
    cp "${KEYS_DIR}/${set_secure_mode_file_2}" "${BINARIES_DIR}/${set_secure_mode_file_2}" || \
        die "Failed to copy set secure mode nk file"
}

case "${BUILD_TYPE}" in
    *50*|*60*)
        if [ "${BYPASS_RODATA_GENERATION}" != "1" ]; then
            if grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_CREATE_RODATA=y" "${BR2_CONFIG}"; then
                generate_custom_encrypted_filesystem
            fi
        fi

        if [ -n "${SECURE_TARGET_BUILD}" ]; then
            # Secure target build, use the custom keys
            write_encrypted_filesystem_key

            if grep -qF "BR2_SUMMIT_SECURE_BOOT=y" "${BR2_CONFIG}" && \
            grep -qF "BR2_PACKAGE_HOST_SECURE_SAM_BA_CIPHER=y" "${BR2_CONFIG}"; then
                # Create the secure boot encryption key
                create_secure_boot_encryption_key
                get_secure_mode_command
            fi

            case "${BUILD_TYPE}" in
                *sd)
                    ;;
                *)
                    # Replace boot.bin with boot.cip in sw-description to support encrypted u-boot-spl
                    sed -i "s/boot.bin/boot.cip/g" "${BINARIES_DIR}/sw-description"
                    ;;
            esac
        fi
        ;;
    *)
        ;;
esac

echo "${BR2_SUMMIT_PRODUCT^^} POST FAKE ROOT COMMON script: done."
