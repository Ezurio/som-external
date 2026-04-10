#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
#
# test_dmcrypt_image.sh
#
# Verifies that dmcrypt_image produces output byte-identical to the Linux
# kernel dm-crypt target (aes-xts-plain64, sector 0 IV, 512-byte sectors).
#
# Must be run as root (losetup + dmsetup require it).
# The dmcrypt_image binary must already be built in the same directory.
#
# Usage:
#   sudo ./test_dmcrypt_image.sh

set -e

BINDIR="$(dirname "$(realpath "$0")")"
C_BIN="${BINDIR}/dmcrypt_image"
WORKDIR="$(mktemp -d /tmp/dmcrypt_test.XXXXXX)"

cleanup() {
	dmsetup remove --retry test_crypt_cmp 2>/dev/null || true
	losetup -d "${LOOP}" 2>/dev/null || true
	rm -rf "${WORKDIR}"
}
trap 'cleanup' EXIT INT TERM

die() { echo "FAIL: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must be run as root (needs losetup + dmsetup)"
[ -x "${C_BIN}" ]    || die "dmcrypt_image not found at ${C_BIN} — run 'make' first"

PLAIN="${WORKDIR}/plain.bin"
RAW_IMG="${WORKDIR}/raw.img"
ENC_KERNEL="${WORKDIR}/enc_kernel.img"
ENC_C="${WORKDIR}/enc_c.img"

# ── 1. generate test data ─────────────────────────────────────────────────────
echo "[1/4] Generating 4 MiB random plaintext and 64-byte AES-256-XTS key …"
dd if=/dev/urandom bs=512 count=8192 of="${PLAIN}" 2>/dev/null
KEY_HEX=$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | xxd -p | tr -d '\n')
echo "    key = ${KEY_HEX}"
SECTORS=$(( $(stat -c %s "${PLAIN}") / 512 ))

# ── 2. kernel path: losetup → dmsetup crypt → dd ─────────────────────────────
echo "[2/4] Kernel path: losetup + dmsetup …"
cp "${PLAIN}" "${RAW_IMG}"
LOOP=$(losetup -f)
losetup "${LOOP}" "${RAW_IMG}"

dmsetup create test_crypt_cmp \
	--table "0 ${SECTORS} crypt aes-xts-plain64 ${KEY_HEX} 0 ${LOOP} 0"

dd if="${PLAIN}" of=/dev/mapper/test_crypt_cmp bs=512 conv=fsync 2>/dev/null

dmsetup remove --retry test_crypt_cmp
losetup -d "${LOOP}"
cp "${RAW_IMG}" "${ENC_KERNEL}"

# ── 3. C binary path ─────────────────────────────────────────────────────────
echo "[3/4] C binary: dmcrypt_image --input …"
"${C_BIN}" \
	--input   "${PLAIN}"  \
	--output  "${ENC_C}"  \
	--key-hex "${KEY_HEX}"

# ── 4. compare ────────────────────────────────────────────────────────────────
echo "[4/4] Comparing …"
MD5_K=$(md5sum "${ENC_KERNEL}" | awk '{print $1}')
MD5_C=$(md5sum "${ENC_C}"      | awk '{print $1}')
echo "    kernel md5 : ${MD5_K}"
echo "    c      md5 : ${MD5_C}"

if [ "${MD5_K}" = "${MD5_C}" ]; then
	echo ""
	echo "PASS — C binary output is byte-identical to the kernel dm-crypt target."
else
	echo ""
	cmp -l "${ENC_KERNEL}" "${ENC_C}" | head -5
	die "C binary output differs from kernel!"
fi
