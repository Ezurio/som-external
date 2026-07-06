#!/bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2026 Ezurio

die() {
	echo "${1}" >&2
	exit 1
}

resolve_cmd() {
	command -v "${1}" >/dev/null 2>&1 ||
		die "${1} not available"
}

find_mtd_device() {
	f=$(grep -lxF "${1}" /sys/class/mtd/mtd*/name 2>/dev/null) ||
		return 1

	f=${f#/sys/class/mtd/}
	f=${f%%/name}
	echo "/dev/${f}"
}

find_ubi_device() {
	f=$(grep -lxF "${1}" /sys/class/ubi/ubi*_*/name 2>/dev/null) ||
		return 1

	f=${f#/sys/class/ubi/}
	f=${f%%/name}
	echo "/dev/${f}"
}

resolve_partition() {
	mtd_dev=$(find_mtd_device "${1}") || true
	if [ -n "${mtd_dev}" ]; then
		echo "mtd ${mtd_dev}"
		return 0
	fi

	ubi_dev=$(find_ubi_device "${1}") || true
	if [ -n "${ubi_dev}" ]; then
		echo "ubi ${ubi_dev}"
		return 0
	fi

	die "Partition ${1} not found in MTD or UBI by name"
}

get_mtd_type() {
	mtd=${1#/dev/}
	cat "/sys/class/mtd/${mtd}/type" 2>/dev/null ||
		die "Unable to read MTD type for ${1}"
}

hash_mtd_partition() {
	dev=${1}
	type=${2}
	size=${3}

	case "${type}" in
	nand)
		nanddump -a --quiet --bb=skipbad --omitoob --length "${size}" "${dev}" | \
			sha256sum | awk '{print $1}'
		;;
	*)
		head -c "${size}" "${dev}" | sha256sum | awk '{print $1}'
		;;
	esac
}

hash_ubi_partition() {
	dev=${1}
	size=${2}

	head -c "${size}" "${dev}" | sha256sum | awk '{print $1}'
}

copy_mtd_partition() {
	src_dev=${1}
	dst_dev=${2}
	size=${3}

	src_mtd=${src_dev#/dev/}
	dst_mtd=${dst_dev#/dev/}

	src_type=$(cat "/sys/class/mtd/${src_mtd}/type") ||
		die "Unable to read source MTD type for ${src_dev}"
	dst_type=$(cat "/sys/class/mtd/${dst_mtd}/type") ||
		die "Unable to read destination MTD type for ${dst_dev}"

	[ "${src_type}" = "${dst_type}" ] ||
		die "MTD type mismatch (${src_type} != ${dst_type})"

	case "${src_type}" in
	nand)
		resolve_cmd nanddump
		resolve_cmd nandwrite
		resolve_cmd flash_erase

		flash_erase "${dst_dev}" 0 0 ||
			die "Failed erasing ${dst_dev}"

		nanddump -a --quiet --bb=skipbad --omitoob --length "${size}" "${src_dev}" | \
			nandwrite --quiet --pad "${dst_dev}" - ||
			die "Failed streaming ${src_dev} to ${dst_dev}"
		;;

	*)
		resolve_cmd dd
		resolve_cmd flash_erase

		flash_erase "${dst_dev}" 0 0 ||
			die "Failed erasing ${dst_dev}"

		dd if="${src_dev}" of="${dst_dev}" bs=1 count="${size}" conv=fsync 2>/dev/null ||
			die "Failed copying ${src_dev} to ${dst_dev}"
		;;
	esac
}

copy_ubi_partition() {
	src_dev=${1}
	dst_dev=${2}
	size=${3}

#	resolve_cmd ubiupdatevol
	resolve_cmd dd

	head -c "${size}" "${src_dev}" | \
		ubiupdatevol "${dst_dev}" -s "${size}" - ||
		die "Failed copying ${src_dev} to ${dst_dev}"
}

[ $# -eq 4 ] ||
	die "Usage: ${0} src_name dst_name size_bytes sha256"

src_name=${1}
dst_name=${2}
size_bytes=${3}
expected_sha256=${4}

[ -n "${src_name}" ] || die "Missing source partition name"
[ -n "${dst_name}" ] || die "Missing destination partition name"
[ -n "${size_bytes}" ] || die "Missing partition size in bytes"
[ -n "${expected_sha256}" ] || die "Missing expected sha256"
[ "${src_name}" != "${dst_name}" ] ||
	die "Source and destination must differ (${src_name})"

resolve_cmd sha256sum

src_info=$(resolve_partition "${src_name}")
src_kind=${src_info%% *}
src_dev=${src_info#* }

dst_info=$(resolve_partition "${dst_name}")
dst_kind=${dst_info%% *}
dst_dev=${dst_info#* }

[ "${src_kind}" = "${dst_kind}" ] ||
	die "Type mismatch for ${src_name} (${src_kind}) and ${dst_name} (${dst_kind})"

case "${src_kind}" in
mtd)
	src_type=$(get_mtd_type "${src_dev}")
	src_hash=$(hash_mtd_partition "${src_dev}" "${src_type}" "${size_bytes}") ||
		die "Failed reading hash from ${src_name}"
	[ "${src_hash}" = "${expected_sha256}" ] ||
		die "Source hash mismatch for ${src_name}: ${src_hash} != ${expected_sha256}"

	copy_mtd_partition "${src_dev}" "${dst_dev}" "${size_bytes}"

	dst_type=$(get_mtd_type "${dst_dev}")
	dst_hash=$(hash_mtd_partition "${dst_dev}" "${dst_type}" "${size_bytes}") ||
		die "Failed reading hash from ${dst_name}"
	[ "${dst_hash}" = "${expected_sha256}" ] ||
		die "Destination hash mismatch for ${dst_name}: ${dst_hash} != ${expected_sha256}"
	;;
ubi)
	src_hash=$(hash_ubi_partition "${src_dev}" "${size_bytes}") ||
		die "Failed reading hash from ${src_name}"
	[ "${src_hash}" = "${expected_sha256}" ] ||
		die "Source hash mismatch for ${src_name}: ${src_hash} != ${expected_sha256}"

	copy_ubi_partition "${src_dev}" "${dst_dev}" "${size_bytes}"

	dst_hash=$(hash_ubi_partition "${dst_dev}" "${size_bytes}") ||
		die "Failed reading hash from ${dst_name}"
	[ "${dst_hash}" = "${expected_sha256}" ] ||
		die "Destination hash mismatch for ${dst_name}: ${dst_hash} != ${expected_sha256}"
	;;
*)
	die "Unsupported partition type ${src_kind}"
	;;
esac

sync
