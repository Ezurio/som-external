#! /bin/sh

BUILD_TYPE=${1}
OLD_KERNEL=${2}
SECURE_BOOT=${3}

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

print_verity() {
    cat << EOF
dm_table="vroot,,${DM_SUFFIX}ro,0 SIZE verity 1
\${boot_dev} \${boot_dev} 4096 4096 BLOCKS OFFSET sha256 HASH SALT"

EOF
}

print_common_60() {
    cat << EOF
setenv bootargs "root=${1} rootwait rootfstype=squashfs ro ubi.fm_autoconvert=1
init=/usr/sbin/fipsInit.sh initlrd=/usr/sbin/${2}
${3}
fips=\${fips:=0} fips_wifi=\${fips_wifi:=0} bootside=\${bootside}"
EOF
}

print_emmc() {
    print_verity

    cat << EOF
setenv bootargs "\${bootargs} dm-mod.create=\"\${dm_table}\"
dm-mod.waitfor=\${boot_dev} root=/dev/dm-0 rootwait rootfstype=squashfs ro"
EOF
}

case ${BUILD_TYPE} in
    som60|ig60|ig60ll|wb50n)
        echo "boot_dev=/dev/ubiblock0_\${bootvol}"
        if ${SECURE_BOOT}; then
            print_verity
            print_common_60 "/dev/dm-0" "pre-systemd-init.sh" \
            "ubi.mtd=ubi,0,0,0${MTD_SUFFIX} ubi.block=0,\${bootvol} quiet ${DM}"
        else
            print_common_60 "\${boot_dev}" "overlayRoot.sh" \
            "ubi.mtd=ubi,0,0,0${MTD_SUFFIX} ubi.block=0,\${bootvol} \${bootargs}"
        fi
        ;;

    som60sd|ig60llsd|wb50nsd)
        echo 'boot_dev=/dev/mmcblk0p5'
        if ${SECURE_BOOT}; then
            print_verity
            print_common_60 "/dev/dm-0" "pre-systemd-init.sh" \
            "resume=/dev/mmcblk0p2 resumewait=5 \${bootargs} quiet ${DM}"
        else
            print_common_60 "\${boot_dev}" "overlayRoot.sh" \
            "resume=/dev/mmcblk0p2 resumewait=5 \${bootargs}"
        fi
        ;;

    *am62*|imx8*)
        print_emmc
        ;;

esac
