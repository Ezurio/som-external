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

${ENCRYPTED_TOOLKIT} && INITTYPE='' || INITTYPE="inittype=overlay"

${CONSOLE_LOGGING} || LOG_LEVEL=quiet

print_verity() {
    cat << EOF
dm_table="vroot,,${DM_SUFFIX}ro,0 SIZE verity 1
\${boot_dev} \${boot_dev} 4096 4096 BLOCKS OFFSET sha256 HASH SALT"

EOF
}

print_common() {
    cat << EOF
if test "\${boot_src}" = "nand" -o -z "\${boot_src}"; then
    boot_dev="/dev/ubiblock0_\${bootvol}"
    UBI_ARGS="ubi.fm_autoconvert=1 ubi.mtd=ubi,0,0,0${MTD_SUFFIX} ubi.block=0,\${bootvol}"
else
    boot_dev="/dev/mmcblk\${mmcdev}p\${rootvol}"
    UBI_ARGS="ubi.fm_autoconvert=1"
fi
setenv bootargs "root=${1} rootwait rootfstype=squashfs ro bootside=\${bootside}
init=/usr/bin/pre-systemd-init.sh ${INITTYPE} \${UBI_ARGS}
fips=\${fips:=0} fips_wifi=\${fips_wifi:=0} ${2}
${LOG_LEVEL} ${KERNEL_EXTRA_CMDS}"
EOF
}

case ${BUILD_TYPE} in
    som60|ig60|ig60ll|wb50n)
        echo "boot_src=nand"
        if ${SECURE_BOOT}; then
            print_verity
            print_common "/dev/dm-0" "${DM}"
        else
            print_common "\${boot_dev}" "\${bootargs}"
        fi
        ;;

    som60sd|ig60llsd|wb50nsd)
        echo 'boot_src=sd;mmcdev=0;rootvol=5'
        if ${SECURE_BOOT}; then
            print_verity
            print_common "/dev/dm-0" "${DM}"
        else
            print_common "\${boot_dev}" \
            "resume=/dev/mmcblk0p2 resumewait=5 \${bootargs}"
        fi
        ;;

    am6*|imx*)
        if ${SECURE_BOOT}; then
            print_verity
            print_common "/dev/dm-0" "${DM}"
        else
            print_common "\${boot_dev}" "\${bootargs}"
        fi
        ;;
esac
