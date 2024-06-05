#!/bin/sh
# Creates the fw_update/select installer with utilities attached.
# This script may be run by buildroot post_image, or manually.
# The output file 'fw_usi' self-extracts when run on a WB.

# set output path/file
FWUSI=${BINARIES_DIR:-.}/fw_usi

# create installer script
cat > "${FWUSI}" << EOF
#!/bin/ash
# fw_usi - fw_update/select installer
# This file contains ustar headers and is to be run directly: 'fw_usi'
# Installs fw_* utilities to rootfs-a/b and reports versions.
# Optionally, use to invoke a fw_update or fw_select command.
# Example: 'fw_usi update -c -f http://server/path/fw.txt'

sh() { \$@ || rv=\$((rv+\$?)); echo; }

rv=0

echo "extracting:"
tls=\$(tail -c +XXXX \$0 | tar -C / -xzv) \
  && echo || { echo Aborted!; exit 2; }

sh fw_update --version

sh fw_select --version

sh fw_select --show

if [ \$rv -eq 0 ]; then
  case \${1#fw_} in
    '') ## assume default operation to install utilities
      sh fw_select --transfer export -- \$(printf "/%s " \${tls})
      ;;

    update|select) ## invoke specified update/select command
      printf "/%s\n" \${tls} >>/tmp/alt_rootfs.transfer-list
      sh fw_\${@#fw_}
      ;;

    *) rv=\$((rv+1)) && echo "v---- usage/syntax: \$@"
  esac
fi

[ \$rv\$? -eq 0 ] && echo "OK" || echo "Error"
exit \$rv
EOF

size=$(($(stat -Lc %s "${FWUSI}")+1))
[ ${size} -ge 1000 ] || size=$((size-1))

sed -i "s,XXXX,${size}," "${FWUSI}"

echo "creating installer"
tar -cvzf "${FWUSI}.tar.gz" -C "${TARGET_DIR:-rootfs-additions-common}" \
	usr/sbin/fw_update usr/sbin/fw_select

cat "${FWUSI}.tar.gz" >> "${FWUSI}"
rm "${FWUSI}.tar.gz"

chmod +x "${FWUSI}"

md5sum "${FWUSI}" \
  |sed "s,\(^[^ ]\+\) .*[/]\(.*\),  \1  \2  $( stat -Lc "%s" "${FWUSI}" ),"
