#!/bin/bash
# create update-list for fw_update
# This script is to be run within the directory containing image files.

# update-list file
fwul=${BINARIES_DIR-.}/fw.txt

# list of image files: [#]name
# names may be 6-10 character length
# prepend with '#' to disable in update-list
#
image1="#at91bs.bin"
image2="#u-boot.bin"
image3="kernel.bin"
image4="rootfs.bin"

# write target-build description
if [ -n "${SUMMIT_RELEASE_STRING}" ]
then
  echo "# ${SUMMIT_RELEASE_STRING}" > ${fwul}
else
  echo "# $(hostname)-${1-?}" > ${fwul}
fi

# write update-list
for n in 1 2 3 4
do
  # construct image var
  eval name=\${image${n}} && image=${name#\#}

  # set line prefix as hash or space
  [ ${image} != ${name} ] && x='#' || x=' '

  imagef=${BINARIES_DIR-.}/${image}

  # skip non-existant files
  [ -e ${imagef} ] || continue

  # write image line: [w/prefix] <md5>  <name>  <bytes>
  md5sum ${imagef} | \
	sed "s,\(^[^ ]\+\) .*[/]\(.*\),${x}  \1  \2  $(stat -Lc "%s" ${imagef})," >>${fwul}
done
echo >> ${fwul}

# apply optional flags or shell lines
echo "  flags -c" >>${fwul}
echo >>${fwul}

# add transfer-list section
cat >> ${fwul} << EOF
# transfer-list
  /etc/summit/profiles.conf
  /etc/network/interfaces
  /etc/ssl
  /root/.ssh
  /etc/dcas.conf

EOF

# display file
echo ${fwul}:
cat ${fwul}
