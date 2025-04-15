#! /bin/sh
# SPDX-License-Identifier: LicenseRef-Ezurio-Clause
# Copyright (C) 2024 Ezurio

set -x -e

if ${OLD_KERNEL}; then 
    MTD_SUFFIX=""
    DM_SUFFIX=""
    # shellcheck disable=SC2016
    DM='rootdelay=1 dm=\"${dm_table}\"'
else
    MTD_SUFFIX=",1"
    DM_SUFFIX=","
    # shellcheck disable=SC2016
    DM='dm-mod.create=\"${dm_table}\" dm-mod.waitfor=${boot_dev}'
fi

${ENCRYPTED_TOOLKIT} && INIT="pre-systemd-init.sh" || INIT="overlayRoot.sh"

${CONSOLE_LOGGING} || LOG_LEVEL=quiet

print_verity() {
    cat << EOF
dm_table="vroot,,${DM_SUFFIX}ro,0 SIZE verity 1
\${boot_dev} \${boot_dev} 4096 4096 BLOCKS OFFSET sha256 HASH SALT"

EOF
}

print_common() {
    cat << EOF
setenv bootargs "root=${1} rootwait rootfstype=squashfs ro bootside=\${bootside}
EOF
}

print_common_60() {
    print_common "${1}"
    cat << EOF
ubi.fm_autoconvert=1 init=/usr/sbin/fipsInit.sh initlrd=/usr/sbin/${INIT} ${LOG_LEVEL}
${2}
fips=\${fips:=0} fips_wifi=\${fips_wifi:=0}"
EOF
}

print_common_emmc() {
    print_common "${1}"
    cat << EOF
init=/usr/sbin/${INIT} ${LOG_LEVEL}
${2}"
EOF
}

case ${BUILD_TYPE} in
    som60|ig60|ig60ll|wb50n)
        echo "boot_dev=/dev/ubiblock0_\${bootvol}"
        if ${SECURE_BOOT}; then
            print_verity
            print_common_60 "/dev/dm-0" \
            "ubi.mtd=ubi,0,0,0${MTD_SUFFIX} ubi.block=0,\${bootvol} ${DM}"
        else
            print_common_60 "\${boot_dev}" \
            "ubi.mtd=ubi,0,0,0${MTD_SUFFIX} ubi.block=0,\${bootvol} \${bootargs}"
        fi
        ;;

    som60sd|ig60llsd|wb50nsd)
        echo 'boot_dev=/dev/mmcblk0p5'
        if ${SECURE_BOOT}; then
            print_verity
            print_common_60 "/dev/dm-0" "${DM}"
        else
            print_common_60 "\${boot_dev}" \
            "resume=/dev/mmcblk0p2 resumewait=5 \${bootargs}"
        fi
        ;;

    *am62*|imx8*)
        echo "boot_dev=/dev/mmcblk\${mmcdev}p\${rootvol}"
        if ${SECURE_BOOT}; then
            print_verity
            print_common_emmc "/dev/dm-0" "${DM}"
        else
            print_common_emmc "\${boot_dev}" "\${bootargs}"
        fi
        ;;
esac
