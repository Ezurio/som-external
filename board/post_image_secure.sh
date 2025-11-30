#!/bin/bash
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

# enable tracing and exit on errors
set -x -e

: "${SECURE_BOOT:=false}"

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SECURE script: starting..."

[ -n "${UBOOT_VER}" ] ||
	UBOOT_VER=$(make -j1 -s --no-print-directory -C "${BASE_DIR}" uboot-show-version | sed '/^make\[/d')

ROOTFS_TYPE=$(sed -rn 's/BR2_TARGET_ROOTFS_([A-Z]+)=y/\L\1/p' "${BR2_CONFIG}" | head -n1)
[ "${ROOTFS_TYPE}" != ext2 ] || ROOTFS_TYPE=ext4

# Secure tooling checks
mkimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkimage
mkenvimage=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/mkenvimage
veritysetup=${HOST_DIR}/sbin/veritysetup

die() { echo "$@" >&2; exit 1; }

size_check () {
    [ "$(stat -Lc "%s" "${BINARIES_DIR}/${1}")" -le "${2}" ] || \
        die "${1} size exceeded ${2} block limit, failed"
}

[ -x "${mkimage}" ] || \
	die "No mkimage found (uboot has not been built?)"

# Get U-Boot environment size
ENV_SIZE=$(sed -rn 's,^CONFIG_ENV_SIZE=(.*),\1,p' "${BUILD_DIR}/uboot-${UBOOT_VER}/.config")

# Check if U-Boot environment is redundant
if grep -qF "CONFIG_SYS_REDUNDAND_ENVIRONMENT=y" "${BUILD_DIR}/uboot-${UBOOT_VER}/.config"; then
MKENVIMGOPT=-r
else
MKENVIMGOPT=
fi

cd "${BINARIES_DIR}"

if [ -f "${TARGET_DIR}/etc/u-boot-initial-env" ]; then
    [ -x "${mkenvimage}" ] || \
        die "No mkenvimage found (uboot has not been built?)"

    # Generate U-Boot environment image
    ${mkenvimage} -p 0 ${MKENVIMGOPT} -s "${ENV_SIZE}" -o uboot.env \
        "${TARGET_DIR}/etc/u-boot-initial-env"
fi

# Create unsecured_images dir and copy off unsigned images
mkdir -p "unsecured_images"
for f in u-boot.dtb u-boot-spl.dtb
do
	[ ! -f "${f}" ] ||
        cp -aft "unsecured_images" "${f}"
done

# Generate dm-verty rootfs
if ${SECURE_BOOT} ; then
    [ -x "${veritysetup}" ] || \
        die "No veritysetup found (host-cryptsetup has not been built?)"

    rm -f rootfs.bin
    cp -f "rootfs.${ROOTFS_TYPE}" rootfs.bin

    size=$(stat --printf="%s" rootfs.bin)
    eval "$(veritysetup --hash-offset="${size}" format rootfs.bin rootfs.bin | \
        sed -r '1d; s/^([^:]+):\s+(.+)/\U\1=\E\2/; s/ /_/g')"

    # Fill boot script with verity parameters
    sed -i \
        -e "s/SALT/${SALT}/g" \
        -e "s/HASH/${ROOT_HASH}/g" \
        -e "s/BLOCKS/${DATA_BLOCKS}/g" \
        -e "s/SIZE/$((DATA_BLOCKS * 8))/g" \
        -e "s/OFFSET/$((DATA_BLOCKS + 1))/g" \
        boot.scr
else
    ln -sf "rootfs.${ROOTFS_TYPE}" "${BINARIES_DIR}/rootfs.bin"
fi

KERNEL_IMAGE=$(sed -rn 's|.*/incbin/\("(Image[^"]+).*|\1|p' kernel.its)

# Compress images for the kernel FIT
while read -r file; do
    case "${file}" in
        *.gz) gzip -9kfn "${file%.*}" ;;
        *.lzo) lzop -9kf "${file%.*}" ;;
        *.lzma) lzma -9kf "${file%.*}" ;;
        *.zst) zstd -9 -kf "${file%.*}" ;;
    esac
done < <(sed -rn 's|.*/incbin/\("([^"]+).*|\1|p' kernel.its | grep '\.\(gz\|lzo\|lzma\|zst\)$')

case ${BUILD_TYPE} in
    *sd|am6*|imx*)
        # Align on the block size of the SD/eMMC
        MKIMAGE_OPT="-B 0x200"
        ;;
    *)
        MKIMAGE_OPT=
        ;;
esac

# Create Kernel FIT image, and store signature in u-boot
if ${SECURE_BOOT} ; then
    ${mkimage} -E ${MKIMAGE_OPT} -f kernel.its -F -K u-boot.dtb -k keys -r kernel.itb
else
    ${mkimage} -E ${MKIMAGE_OPT} -f kernel.its kernel.itb
fi

hash_check() {
	for i in "$@"; do
		openssl mac -macopt key:orboDeJITITejsirpADONivirpUkvarP -digest sha256 -in  "${i}" hmac | \
            tr '[:upper:]' '[:lower:]' | \
			diff -is - "${TARGET_DIR}/usr/lib/fipscheck/${i##*/}.hmac" || \
			die "FIPS Hash mismatch to the certified for ${i##*/}"
	done
}

create_secure_boot_encrypted_uboot_spl() {
    # Check if the Secure SAM-BA Cipher Tool is available
    samba_cipher_tool_dir="${HOST_DIR}/opt/secure-sam-ba-cipher"
    [ -f "${samba_cipher_tool_dir}/sam_genimage.py" ] || \
        die "No Secure SAM-BA Cipher Tool found - is the host-secure-sam-ba-cipher package enabled?"

    customer_key_config="${KEYS_DIR}/customer_key_config.yaml"
    [ -f "${customer_key_config}" ] || \
        die "No customer key config file found in the keys directory"

    # Generate the encrypted U-Boot SPL file
    "${HOST_DIR}/bin/python3" "${samba_cipher_tool_dir}/sam_genimage.py" \
        -c "${customer_key_config}" \
        u-boot-spl.bin \
        bootstrap_sama5d3x.cip

    # Verify the encrypted U-Boot SPL file was created successfully
    [ -f bootstrap_sama5d3x.cip ] || \
        die "Failed to generate encrypted U-Boot SPL"
    
    rm -f "${customer_key_config}"
}

case $(sed -rn 's/BR2_SUMMIT_FIPS_([0-9]+)=y/\1/p' "${BR2_CONFIG}") in
    11)
        hash_check \
            "${BINARIES_DIR}/${KERNEL_IMAGE}" \
            "${TARGET_DIR}/usr/bin/fipscheck" \
            "${TARGET_DIR}/usr/lib/libfipscheck.so.1" \
            "${TARGET_DIR}/usr/lib/ossl-modules/fips.so"
        ;;
esac

case ${BUILD_TYPE} in
som60*|ig60*|wb50n*)
    if ${SECURE_BOOT} ; then
        # Create keys if not present
        if [ ! -f keys/key.bin ]; then
            mkdir -p keys
            # Create random key, for AES128, key is 16 bytes long
            dd if=/dev/random of=keys/key.bin bs=16 count=1
            # Create random IV, AES block is 16 bytes, regardless of key size
            dd if=/dev/random of=keys/key-iv.bin bs=16 count=1
        fi

        # Create U-Boot FIT image (encrypted), and store key, IV and signature in SPL
        ${mkimage} -E ${MKIMAGE_OPT} -f u-boot.its -F -K u-boot-spl.dtb -k keys -r u-boot.itb
    else
        # Create U-Boot FIT image (unencrypted)
        ${mkimage} -E ${MKIMAGE_OPT} -f u-boot.its u-boot.itb
    fi

    ln -sf u-boot.itb u-boot.bin

    # Create final SPL FIT with appended keyed DTB
    cat u-boot-spl-nodtb.bin u-boot-spl.dtb > u-boot-spl.bin

    case ${BUILD_TYPE} in
    *sd)
        ${mkimage} -T atmelimage -d u-boot-spl.bin boot.bin

        if [ -n "${SECURE_TARGET_BUILD}" ]; then
            create_secure_boot_encrypted_uboot_spl

            # Rename the encrypted, bootstrap binary to 'boot.cip' for use with an SD card image (no
            # PMECC header)
            mv -f bootstrap_sama5d3x.cip boot.cip || \
                die "Failed to rename the encrypted, bootstrap binary"
        fi
        ;;
    *)
        atmel_pmecc_params=${BUILD_DIR}/uboot-${UBOOT_VER}/tools/atmel_pmecc_params
        [ -x "${atmel_pmecc_params}" ] || \
            die "no atmel_pmecc_params found (uboot has not been built?)"

        # Generate Atmel PMECC boot.bin from SPL
        ${mkimage} -T atmelimage -n "$(${atmel_pmecc_params})" -d u-boot-spl.bin boot.bin

        if ${SECURE_BOOT} ; then
            # Generate key transition support
            if grep -qF boot1.bin sw-description ; then
                cp -f boot.bin boot1.bin
                echo "keyrev=1" >> "${TARGET_DIR}/etc/u-boot-initial-env"
                ${mkenvimage} ${MKENVIMGOPT} -s "${ENV_SIZE}" -o uboot1.env u-boot1-initial-env
            fi

            if [ -n "${SECURE_TARGET_BUILD}" ]; then
                create_secure_boot_encrypted_uboot_spl

                # Save off the raw PMECC header
                dd if=boot.bin of=boot.cip bs=208 count=1

                # Concatenate a PMECC header to the encrypted, bootstrap binary
                cat bootstrap_sama5d3x.cip >> boot.cip

                # Cleanup
                rm -f bootstrap_sama5d3x.cip
            fi
        fi
        ;;
    esac

    # Check u-boot sizes against flash partitions
    case ${BUILD_TYPE} in
    wb45n)
        size_check u-boot.bin $((3*128*1024))
        size_check kernel.bin $((18*128*1024))
        ;;

    som60*|wb50*|ig60ll*)
        size_check boot.bin $((64*1024))
        size_check u-boot.bin $((7*128*1024))
        ;;

    ig60*)
        size_check boot.bin $((64*1024))
        size_check u-boot.bin $((3*128*1024))
        ;;
    esac
    ;;

imx*)
    if ${SECURE_BOOT} ; then
        export KEY_PATH
        make -C "${BASE_DIR}" uboot-rebuild EXT_DTB="${BINARIES_DIR}/u-boot.dtb"
    fi
    ;;

am6*)
    if ${SECURE_BOOT} ; then
        export KEY_PATH
        make -C "${BASE_DIR}" uboot-rebuild EXT_DTB="${BINARIES_DIR}/u-boot.dtb"
        make -C "${BASE_DIR}" ti-k3-r5-loader-rebuild
		if [ -n "${SECURE_TARGET_BUILD}" ]; then
			case "${BUILD_TYPE}" in
				am62*)
					ln -sf tiboot3-am62x-hs-carbon.bin "${BINARIES_DIR}/tiboot3.bin"
					;;
				am67*)
					ln -sf tiboot3-am67x-hs-carbon.bin "${BINARIES_DIR}/tiboot3.bin"
					;;
			esac
		fi
    fi
    ;;
esac

# Restore unsecured components
find unsecured_images -type f -exec mv -vft . {} +;
rm -rf unsecured_images/

cd -

echo "${BR2_SUMMIT_PRODUCT^^} POST IMAGE SECURE script: done."
