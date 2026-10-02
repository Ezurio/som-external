#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio

# Generate the summit-prov-imx provisioning artifacts on the build host.
#
# Usage: generate-artifacts.sh SRC_DIR OUTPUT_DIR
#
# OUTPUT_DIR receives the files installed in /usr/share/summit-prov-imx.
# Non-secure builds also get a copy of summit-prov-imx.sh in OUTPUT_DIR with
# the per-build decryption key filled in.
#
# Environment:
#   SECURE              "y" to wrap the fleet key for ELE (AHAB builds);
#                       empty for the non-secure AES-CBC payload
#   SIG_DATA_PATH       directory with prov_data/. Secure builds also read
#                       spsdk_ahab.yaml and summit-prov-imx/
#                       {nxp-prod-ka-public.bin,oem-ka-private.pem,
#                       fleet-aes-256.bin}
#   PYTHON              host python3 with cryptography and PyYAML; nxpimage
#                       must be on PATH (secure only)
#   FAMILY              SPSDK family name, e.g. mx93 (secure only)
#   ISSUE_DATE          fixed signed-message issue date, YYYY-MM (secure only)
#   SIGNER              optional SPSDK signer overriding spsdk_ahab.yaml
#   HSM_PKCS11_LIBRARY  PKCS#11 module, required when SIGNER is type=pkcs11

set -eu

die() {
	echo "summit-prov-imx: $*" >&2
	exit 1
}

[ $# -eq 2 ] || die "usage: $0 SRC_DIR OUTPUT_DIR"
src_dir=$1
out_dir=$2
work_dir="${out_dir}.work"
prov_data_dir="${SIG_DATA_PATH}/prov_data"
crypto_dir="${SIG_DATA_PATH}/summit-prov-imx"
archive="${out_dir}/prov-data.tar.gz"

[ -d "${prov_data_dir}/keystore" ] || \
	die "No keystore directory found in ${prov_data_dir}"

# Never leave the plaintext provisioning archive behind on failure.
trap 'rm -f "${archive}"' EXIT

rm -rf "${out_dir}" "${work_dir}"
mkdir -p "${out_dir}"

# Build a deterministic archive from the product's prov_data directory.
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
	-C "${prov_data_dir}" -czf "${archive}" .
# ELE decrypts the payload in one operation, limited by the kernel driver's
# 128 KiB shared-memory buffer. The same limit applies to non-secure builds
# so a prov_data that works there also works in a secure build.
[ "$(stat -c %s "${archive}")" -le 65520 ] || \
	die "Provisioning archive exceeds the 65520-byte ELE limit"

# Without secure boot, encrypt the archive with a random per-build
# AES-256-CBC key that is embedded in the wrapper script. The key is in
# cleartext in the rootfs, so this does not protect prov_data and is not for
# production. A per-build key is used so that no customer key is ever exposed
# this way.
if [ -z "${SECURE:-}" ]; then
	key=$(openssl rand -hex 32)
	iv=$(openssl rand -hex 16)
	openssl enc -aes-256-cbc -K "${key}" -iv "${iv}" \
		-in "${archive}" \
		-out "${out_dir}/prov-data.tar.gz.aes-cbc"
	rm -f "${archive}"

	sed -E \
		-e "s/^(DECRYPT_KEY=).*/\1\"${key}\"/" \
		-e "s/^(DECRYPT_IV=).*/\1\"${iv}\"/" \
		"${src_dir}/summit-prov-imx.sh" > "${out_dir}/summit-prov-imx.sh"
	grep -q "^DECRYPT_KEY=\"${key}\"" "${out_dir}/summit-prov-imx.sh" || \
		die "Failed to store the decryption key in summit-prov-imx.sh"
	chmod 0700 "${out_dir}/summit-prov-imx.sh"

	cd "${out_dir}"
	sha256sum prov-data.tar.gz.aes-cbc > SHA256SUMS
	exit 0
fi

# Secure builds wrap the fleet key for ELE and encrypt the archive with
# AES-256-GCM. Only public or wrapped material is installed; the fleet key
# never enters the image.
[ -f "${SIG_DATA_PATH}/spsdk_ahab.yaml" ] || \
	die "SPSDK AHAB configuration not found: ${SIG_DATA_PATH}/spsdk_ahab.yaml"

for artifact in nxp-prod-ka-public.bin oem-ka-private.pem fleet-aes-256.bin; do
	[ -f "${crypto_dir}/${artifact}" ] || \
		die "Missing i.MX provisioning crypto input: ${crypto_dir}/${artifact}"
done

# Reject derived intermediates. The generator creates these temporarily in
# its work directory, consumes them while wrapping the fleet key, and
# removes them.
for secret in oem_import_mk_sk.bin oem_import_wrap_sk.bin \
	      oem_import_cmac_sk.bin shared_secret.bin; do
	[ ! -e "${crypto_dir}/${secret}" ] || \
		die "Unneeded secret provisioning material must not be present in ${crypto_dir}: ${secret}"
done

[ "$(stat -c %s "${crypto_dir}/fleet-aes-256.bin")" -eq 32 ] || \
	die "fleet-aes-256.bin must be exactly 32 bytes"

set --
if [ -n "${SIGNER:-}" ]; then
	case "${SIGNER}" in
	type=pkcs11*)
		if [ -z "${HSM_PKCS11_LIBRARY:-}" ] || [ ! -e "${HSM_PKCS11_LIBRARY}" ]; then
			die "The Cloud HSM backend did not provide a usable PKCS#11 library"
		fi
		;;
	esac
	set -- --signer "${SIGNER}"
fi

"${PYTHON}" "${src_dir}/generate_ele_artifacts.py" \
	--sig-data-path "${SIG_DATA_PATH}" \
	--crypto-dir "${crypto_dir}" \
	--nxp-prod-ka-public "${crypto_dir}/nxp-prod-ka-public.bin" \
	--output-dir "${out_dir}" \
	--work-dir "${work_dir}" \
	--family "${FAMILY}" \
	--issue-date "${ISSUE_DATE}" \
	"$@"
rmdir "${work_dir}"

check_size() {
	[ "$(stat -c %s "${out_dir}/$1")" -eq "$2" ] || \
		die "Generated $1 must be $2 bytes"
}
check_size key-exchange.bin 576
check_size oem-ka-public.bin 64
check_size key-import-tlv.bin 141

# Encrypt the archive with a fresh 96-bit GCM nonce.
"${PYTHON}" "${src_dir}/encrypt_prov_data.py" \
	"${crypto_dir}/fleet-aes-256.bin" \
	"${archive}" \
	"${out_dir}/prov-data.tar.gz.aes-gcm"
rm -f "${archive}"

cd "${out_dir}"
sha256sum key-exchange.bin oem-ka-public.bin key-import-tlv.bin \
	prov-data.tar.gz.aes-gcm > SHA256SUMS
