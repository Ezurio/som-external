#! /bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2025 Ezurio

# enable tracing and exit on errors
set -x -e -o pipefail

[ -n "${BR2_SUMMIT_PRODUCT}" ] || \
	BR2_SUMMIT_PRODUCT="$(sed -n 's,^BR2_DEFCONFIG=".*/\(.*\)_defconfig"$,\1,p' "${BR2_CONFIG}")"

echo "${BR2_SUMMIT_PRODUCT^^} POST FAKE ROOT COMMON script: starting..."

die() { echo "$@" >&2; exit 1; }

generate_custom_encrypted_filesystem() {
    if [ -n "${KEYS_DIR}" ]; then
        # Keys directory is set, use the custom key
        encrypted_filesystem_key="${KEYS_DIR}/encrypted_filesystem_key.txt"
        [ -f "${encrypted_filesystem_key}" ] || \
            die "Encrypted filesystem key not found"

        # Generate the encrypted filesystem
        set +x
        (cd "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common" && sudo ./mkrodata.sh \
            "$(cat "$encrypted_filesystem_key")" \
            "${KEYS_DIR}/update_signing.crt" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.crt" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.key" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/ca.crt")
        set -x
    else
        # Keys directory is not set, use the default filesystem encryption key
        encrypted_filesystem_key="${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/key-fs.bin"
        [ -f "${encrypted_filesystem_key}" ] || \
            die "Encrypted filesystem key not found"

        # Generate the encrypted filesystem
        set +x
        (cd "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common" && sudo ./mkrodata.sh \
            "${encrypted_filesystem_key}" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/update_signing.crt" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.crt" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/server.key" \
            "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/configs-common/keys/rest-server/ca.crt")
        set -x
    fi

    [ -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/rodata.img" ] || \
        die "Failed to generate encrypted filesystem"
    mkdir -p "${TARGET_DIR}/etc/rodata"
    mv -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/rodata.img" \
        "${TARGET_DIR}/etc/rodata/rodata.img"
    sudo chown "${USER}:${GROUP}" "${TARGET_DIR}/etc/rodata/rodata.img"

    [ -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/rodata_manifest.txt" ] || \
        die "Failed to generate encrypted filesystem manifest"
    mv -f "${BR2_EXTERNAL_SUMMIT_SOM_PATH}/board/scripts-common/rodata_manifest.txt" \
        "${BINARIES_DIR}/rodata_manifest.txt"
}

write_encrypted_filesystem_key() {
    fdtput=${HOST_DIR}/bin/fdtput
    [ -x "${fdtput}" ] || \
    	die "No fdtput found (uboot has not been built?)"

    encrypted_filesystem_key="${KEYS_DIR}/encrypted_filesystem_key.txt"
    [ -f "${encrypted_filesystem_key}" ] || \
    	die "No encrypted filesystem key found in the keys directory"

    set +x
    encrypted_filesystem_key=$(sed -r 's/(.{8})/\1 /g' -i "${encrypted_filesystem_key}" | sed 's/[[:space:]]*$//')
    ${fdtput} -p -t x "${BINARIES_DIR}/u-boot.dtb" \
        /encryption \
        "${BINARIES_DIR}/u-boot.dtb" \
        "summit,fs-key" \
        "${encrypted_filesystem_key}" || \
    	    die "Failed to write encrypted filesystem key to U-Boot device tree"
    set -x
}

create_secure_boot_encryption_key() {
	# Check if the Secure SAM-BA Cipher Tool is available
	samba_cipher_tool="${HOST_DIR}/opt/secure-sam-ba-cipher/secure-sam-ba-cipher.py"
	[ -f "${samba_cipher_tool}" ] || \
		die "No Secure SAM-BA Cipher Tool found"

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
    "${HOST_DIR}/bin/python3" "${samba_cipher_tool}" customer-key -d sama5d3x -l "${license_path}" \
        -k "$(cat "${secure_boot_encryption_key}")" -o "${BINARIES_DIR}/customer_key.cip" \
        -pk "${license_key}" -pp "$(cat "${license_passcode}")"
    set -x

	# Verify the customer key files were created successfully
	[ -f "${BINARIES_DIR}/customer_key_sama5d3x.cip" ] || \
		die "Failed to generate customer key"
	[ -f "${BINARIES_DIR}/customer_key_sama5d3x_nk.cip" ] || \
		die "Failed to generate customer key"
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

if grep -qF "BR2_PACKAGE_SUMMIT_ENCRYPTED_STORAGE_TOOLKIT_CREATE_RODATA=y" "${BR2_CONFIG}"; then
    generate_custom_encrypted_filesystem
fi

if [ -n "${KEYS_DIR}" ]; then
    # Keys directory is set, use the custom keys
    write_encrypted_filesystem_key
    create_secure_boot_encryption_key
    get_secure_mode_command

    # Replace boot.bin with boot.cip in sw-description to support encrypted u-boot-spl
    sed -i "s/boot.bin/boot.cip/g" "${BINARIES_DIR}/sw-description"
fi

echo "${BR2_SUMMIT_PRODUCT^^} POST FAKE ROOT COMMON script: done."
