#!/bin/bash
#
# Script to add x509 certificate to binary/ELF
# for booting application images
# The certificate format used here is different from
# the format used by ROM.

# Variables
TSIGN_KEY=rsa4k.pem
VALID_SHAS="sha512 sha384 sha256"
OUTPUT=x509-firmware.bin
TEMP_X509=$(mktemp tmp.x509cert.XXX)
X509_TEMPLATE=$(mktemp tmp.x509template.XXX)
CERT=$(mktemp tmp.signedcert.XXX)
VALID_ENC="ENCRYPT DKEY_ENCRYPT"
RAND_KEY=eckey.pem
VALID_CORES="a53_cl0_c0 a53_cl0_c1 a53_cl0_c2 a53_cl0_c3 hsm0 mcu_m4fss0_c0 r5_cl0_c0 mcu_r5_cl0_c0 main_r5_cl0_c0 c7_cl0_c0 c7_cl1_c0 "
SHA=sha512
CORE=a53_cl0_c0
LOADADDR=0x70000000
# Authentication type. Valid values are 0,1,2
AUTH_TYPE=0
NO_BOOT=1
COPY_AS_HOST=0
N_PADDING_BYTES=0

# Variables for encryption
ENC_IV_VAL=0000
ENC_RS_VAL=0000
ENC_KD_INDEX_VAL=0
ENC_KD_SALT_VAL=0000
enc_valid=0

FIREWALL_CONF_AVAIL=0
FIREWALL_CONF_FILE=""
FIREWALL_EXTENSION=""

KEY_INFO_CONF_AVAIL=0
AUTH_KEYRING_ID=0
ENC_KEYRING_ID=0

KEYRING_INFO_CONF_AVAIL=0
NUM_ASYMM_KEYS=0
NUM_SYMM_KEYS=0

MCELF_CONF_AVAIL=0

declare -A sha_oids
sha_oids["sha256"]=2.16.840.1.101.3.4.2.1
sha_oids["sha384"]=2.16.840.1.101.3.4.2.2
sha_oids["sha512"]=2.16.840.1.101.3.4.2.3
sha_oids["sha224"]=2.16.840.1.101.3.4.2.4

declare -A core_ids
core_ids["a53_cl0_c0"]=0x20
core_ids["a53_cl0_c1"]=0x21
core_ids["a53_cl0_c2"]=0x22
core_ids["a53_cl0_c3"]=0x23
core_ids["hsm0"]=0x80
core_ids["mcu_m4fss0_c0"]=0x18
core_ids["r5_cl0_c0"]=0x1
core_ids["mcu_r5_cl0_c0"]=0x3
core_ids["main_r5_cl0_c0"]=0x4
core_ids["c7_cl0_c0"]=0x30
core_ids["c7_cl1_c0"]=0x31

# We always want SWREV to be 1 except for the negative tests which must set to 0
# to confirm rejection
#source .config
if [[ ${CONFIG_SEC_BOARDCFG_SWREV_NEG_TEST} = 'y' ]]; then
	SWREV=0
else
	SWREV=1
fi

gen_key() {
	openssl ecparam -out $RAND_KEY -name prime256v1 -genkey
	KEY=$RAND_KEY
}

gen_ecdsakey() {
	openssl ecparam -out $TSIGN_KEY -name prime256v1 -genkey
	SIGN_KEY=$TSIGN_KEY
}

gen_rsakey() {
	openssl genrsa -out $TSIGN_KEY 4096
	SIGN_KEY=$TSIGN_KEY
}

gen_enckey() {
	echo "Generating Random Encryption Key of 32 bytes:"
	ENC_KEY=$(mktemp tmp.enckey.XXX)
	openssl rand -hex 32 > "$ENC_KEY"
}

gen_enciv() {
	echo "Generating Random Encryption IV of 16 bytes:"
	ENC_IV=$(mktemp tmp.enciv.XXX)
	openssl rand -hex 16 > "$ENC_IV"
}

gen_encrs() {
	echo "Generating Random Tail String of 32 bytes:"
	ENC_RS=$(mktemp tmp.encrs.XXX)
	openssl rand -hex 32 > "$ENC_RS"
}

gen_encsalt() {
	echo "Generating SALT for HKDF2 Key generation of 32 bytes:"
	ENC_SALT=$(mktemp tmp.encsalt.XXX)
	openssl rand -hex 32 > "$ENC_SALT"
}

#Function to extract segment offsets and sizes using readelf
extract_segments() {
	readelf -l "$1" | awk '/LOAD/ {print $2,$5}' | sed 's/0x//g'
}

image_encrypt() {
	echo
	echo "Image Encryption is enabled :"
	if [ -z "$ENC_KEY" ]; then
		gen_enckey
		echo "Note: Encryption key is available in enckey.txt:"
	fi

	if [ -z "$ENC_IV" ]; then
		gen_enciv
	fi

	if [ -z "$ENC_RS" ]; then
		gen_encrs
	fi

	ENC_IV_VAL=`cat $ENC_IV`
	ENC_RS_VAL=`cat $ENC_RS`
	echo "ENC_KEY = $ENC_KEY"
	echo "ENC_IV  = $ENC_IV_VAL"
	echo "ENC_RS  = $ENC_RS_VAL"
	ENC_TMP_BIN=$(mktemp enc_tmp.XXX)
	ENC_RS_BIN=$(mktemp enc_rs.XXX)
	ENC_BIN_RS_BIN=$(mktemp enc_bin_rs.XXX)
	if [ "$MCELF_CONF_AVAIL" -eq 1 ]; then
		#Check for necessary tools
		if ! command -v openssl &> /dev/null || ! command -v readelf &> /dev/null || ! command -v dd &> /dev/null || ! command -v truncate &> /dev/null; then
			echo "openssl, readelf, dd, and truncate are required but not installed."
			exit 1
		fi

		#Create temp files to work
		MCELF_BIN=$(mktemp mcelf_bin.XXX)
		SEGMENTS_BIN=$(mktemp segments_bin.XXX)
		ENC_SEGMENTS_BIN=$(mktemp enc_segments_bin.XXX)

		#Make a copy of the original ELF file to work on
		cp $BIN  $MCELF_BIN

		ENC_BIN=$BIN"-ENC"
		cp $MCELF_BIN  $ENC_BIN

		#Extract segment offsets and sizes
		segments=$(extract_segments "$MCELF_BIN")

		#Extract the offset and size of the first LOAD segment
		first_segment_offset=$(echo "$segments" | awk 'NR==1 {print $1}')
		first_segment_size=$(echo "$segments" | awk 'NR==1 {print $2}')

		#Calculate the start and end of the encryption range
		encryption_start=$((0x$first_segment_offset))
		encryption_end=0

		#Find the end of the last LOAD segment
		while read -r offset size; do
			segment_end=$((0x$offset + 0x$size))
			if [ "$segment_end" -gt "$encryption_end" ]; then
				encryption_end=$segment_end
			fi
		done <<< "$segments"

		#Calculate the size to be encrypted
		encryption_size=$((encryption_end - encryption_start))

		N_PADDING_BYTES=$(($encryption_size % 16))
		if [ "$N_PADDING_BYTES" -ne 0 ]; then
			N_PADDING_BYTES=$((16-$N_PADDING_BYTES))
		fi

		#Copy the part to be encrypted to a temporary file
		dd if="$MCELF_BIN" bs=1 skip=$encryption_start count=$encryption_size of="$SEGMENTS_BIN" status=none

		#Ensure the temporary file size is a multiple of 16 bytes
		truncate -s %16 "$SEGMENTS_BIN"

		xxd -r -p $ENC_RS $ENC_RS_BIN
		cat $SEGMENTS_BIN  $ENC_RS_BIN > $ENC_BIN_RS_BIN
		
		if [ "$IMG_ENC" == "ENCRYPT" ];then
			openssl aes-256-cbc -e -K `cat $ENC_KEY` -iv $ENC_IV_VAL -in $ENC_BIN_RS_BIN -out $ENC_SEGMENTS_BIN -nopad
		else
			echo
			echo "Deriving Encryption Key using HKDF2 scheme :"
			if [ -z "$ENC_SALT" ]; then
				gen_encsalt
			fi
			ENC_KD_INDEX_VAL=1
			ENC_KD_SALT_VAL=`cat $ENC_SALT`
			echo "	ENC_KEY_INDEX  = $ENC_KD_INDEX_VAL"
			echo "	ENC_KEY_SALT  = $ENC_KD_SALT_VAL"
			xxd -r -p $ENC_KEY enc_key.bin
			echo -n '01'| xxd -r -p > 1.bin
			openssl dgst -sha512 -mac hmac -macopt hexkey:`cat $ENC_SALT` enc_key.bin | sed -e 's/.* //g' > encprk.txt
			openssl dgst -sha512 -mac hmac -macopt hexkey:`cat encprk.txt` 1.bin | sed -e 's/.* //g' > encgenkey.txt
			openssl aes-256-cbc -e -K `head -c 64 encgenkey.txt` -iv $ENC_IV_VAL -in enc_bin_rs.bin -out $ENC_SEGMENTS_BIN -nopad
		fi

		#Copy the encrypted data back to the original position in the output file
		dd if="$ENC_SEGMENTS_BIN" bs=1 of="$ENC_BIN" seek=$encryption_start conv=notrunc status=none

		#Clean up temporary files
		rm -f "$MCELF_BIN" "$SEGMENTS_BIN" "$ENC_SEGMENTS_BIN"
	else
		ORG_BIN_SIZE=`cat $BIN | wc -c`
		N_PADDING_BYTES=$(($ORG_BIN_SIZE % 16))
		if [ "$N_PADDING_BYTES" -ne 0 ]; then
			N_PADDING_BYTES=$((16-$N_PADDING_BYTES))
		fi
		cp $BIN  $ENC_TMP_BIN
		truncate -s %16 $ENC_TMP_BIN
		xxd -r -p $ENC_RS $ENC_RS_BIN
		cat $ENC_TMP_BIN  $ENC_RS_BIN > $ENC_BIN_RS_BIN
		ENC_BIN=$BIN"-ENC"
		if [ "$IMG_ENC" == "ENCRYPT" ];then
			openssl aes-256-cbc -e -K "$(xxd -p -c 32 $ENC_KEY)" -iv $ENC_IV_VAL -in $ENC_BIN_RS_BIN -out $ENC_BIN -nopad
		else
			echo
			echo "Deriving Encryption Key using HKDF2 scheme :"
			if [ -z "$ENC_SALT" ]; then
				gen_encsalt
			fi
			ENC_KD_INDEX_VAL=1
			ENC_KD_SALT_VAL=`cat $ENC_SALT`
			echo "	ENC_KEY_INDEX  = $ENC_KD_INDEX_VAL"
			echo "	ENC_KEY_SALT  = $ENC_KD_SALT_VAL"
			xxd -r -p $ENC_KEY enc_key.bin
			echo -n '01'| xxd -r -p > 1.bin
			openssl dgst -sha512 -mac hmac -macopt hexkey:`cat $ENC_SALT` enc_key.bin | sed -e 's/.* //g' > encprk.txt
			openssl dgst -sha512 -mac hmac -macopt hexkey:`cat encprk.txt` 1.bin | sed -e 's/.* //g' > encgenkey.txt
			openssl aes-256-cbc -e -K `head -c 64 encgenkey.txt` -iv $ENC_IV_VAL -in enc_bin_rs.bin -out $ENC_BIN -nopad
		fi
	fi
	echo "BINARY ENCRYPTION SUCCESS: Generated $ENC_BIN"
	echo
	echo
	# Remove temporary files
	rm -f "$ENC_TMP_BIN" "$ENC_RS_BIN" "$ENC_BIN_RS_BIN"
}
declare -A options_help
usage() {
	if [ -n "$*" ]; then
		echo "ERROR: $*"
	fi
	echo -n "Usage: $0 "
	for option in "${!options_help[@]}"
	do
		arg=`echo ${options_help[$option]}|cut -d ':' -f1`
		if [ -n "$arg" ]; then
			arg=" $arg"
		fi
		echo -n "[-$option$arg] "
	done
	echo
	echo -e "\nWhere:"
	for option in "${!options_help[@]}"
	do
		arg=`echo ${options_help[$option]}|cut -d ':' -f1`
		txt=`echo ${options_help[$option]}|cut -d ':' -f2`
		tb="\t\t\t"
		if [ -n "$arg" ]; then
			arg=" $arg"
			tb="\t"
		fi
		echo -e "   -$option$arg:$tb$txt"
	done
	echo
	echo "Examples of usage:-"
	echo "# Generate x509 certificate with random key from elf"
	echo "    CROSS_COMPILE=arm-linux-gnueabihf- $0 -b ti-sci-firmware-am65x.elf -o dmsc.bin -l 0x40000"
	echo "# Generate x509 certificate with random key from bin"
	echo "    $0 -b ti-sci-firmware-am65x.bin -o dmsc.bin -l 0x40000"
}

options_help[b]="bin_file:Bin file that needs to be signed"
options_help[k]="key_file:file with key inside it. If not provided script generates a random key."
options_help[o]="output_file:Name of the final output file. default x509-firmware.bin"
options_help[c]="core:target core on which the image would be running. Default is m3. Valid option are $VALID_CORES"
options_help[d]=":Countersign DMSC firmware image. This signs a previously signed image for a second time."
options_help[s]="sha_type:sha type to be used for certificate generation. Default is sha512. Valid option are $VALID_SHAS"
options_help[l]="loadaddr: Target load address of the binary in hex. Default to $LOADADDR"
options_help[a]="authentication type: Whether to move image to specified destination address or authenticate image in place or move image to certificate start. Default is move to destination address"
options_help[n]="No boot: Perform load only. Boot i.e configuring reset vector is not required."
# Help for encryption options
options_help[y]="image_encryption:Default is disabled. Valid options are $VALID_ENC"
options_help[e]="enc_key_file:txt file with key inside it. If not provided script generates a random key."
options_help[i]="enc_iv_file:txt file with Encryption Initial Vector(16 bytes) inside it. If not provided script generates a random IV."
options_help[r]="enc_rs_file:txt file with Encryption Tail String(32 bytes) inside it. If not provided script generates a random string."
# Help for firewall configuration options
options_help[f]="firewall configuration file"
options_help[p]="Target processor host id"
# Help for keyring configuration options
options_help[g]="key ring index"
options_help[j]="key ring number of asymmetric keys"
options_help[m]="key ring number of symmetric keys"
# Help for mcelf configuration
options_help[q]="MCELF file:Default is disabled."

while getopts "e:y:i:r:b:k:o:c:ds:a:l:nf:p:g:j:qm:h" opt
do
	case $opt in
	b)
		BIN=$OPTARG
	;;
	k)
		KEY=$OPTARG
	;;
	o)
		OUTPUT=$OPTARG
	;;
	l)
		LOADADDR=$OPTARG
	;;
	s)
		SHA=$OPTARG
		sha_valid=0
		for tsha in $VALID_SHAS
		do
			if [ "$tsha" == "$SHA" ]; then
				sha_valid=1
			fi
		done
		if [ $sha_valid == 0 ]; then
			usage "Invalid sha input $SHA"
			exit 1
		fi
	;;
	c)
		CORE=$OPTARG
		core_valid=0
		for tcore in $VALID_CORES
		do
			if [ "$tcore" == "$CORE" ]; then
				core_valid=1
			fi
		done
		if [ $core_valid == 0 ]; then
			usage "Invalid target core $CORE"
			exit 1
		fi
	;;
	d)
		CERTTYPE=3	# CERT_TYPE_FIRMWARE_COUNTERSIGN
	;;
	a)
		AUTH_TYPE=$OPTARG
		;;
	n)
		NO_BOOT=1
		;;
	e)
		ENC_KEY=$OPTARG
	        ;;
	i)
		ENC_IV=$OPTARG
	        ;;
	r)
		ENC_RS=$OPTARG
	        ;;
	f)
		FIREWALL_CONF_FILE=$OPTARG
		FIREWALL_CONF_AVAIL=1
			;;
	g)
		AUTH_KEYRING_ID=$OPTARG
		KEY_INFO_CONF_AVAIL=1
			;;
	j)
		NUM_ASYMM_KEYS=$OPTARG
		KEYRING_INFO_CONF_AVAIL=1
			;;
	m)
		NUM_SYMM_KEYS=$OPTARG
		KEYRING_INFO_CONF_AVAIL=1
			;;
	q)
		MCELF_CONF_AVAIL=1
			;;
	p)
		COPY_AS_HOST=$OPTARG
			;;
	y)
		IMG_ENC=$OPTARG
		enc_valid=0
		for tenc in $VALID_ENC
		do
			if [ "$tenc" == "$IMG_ENC" ]; then
				enc_valid=1
			fi
		done
		if [ $enc_valid == 0 ]; then
			usage "Invalid Encrypt Option $IMG_ENC"
			exit 1
		fi
	        ;;
	h)
		usage
		exit 0
	;;
	\?)
		usage "Invalid Option '-$OPTARG'"
		exit 1
	;;
	:)
		usage "Option '-$OPTARG' Needs an argument."
		exit 1
	;;
	esac
done

if [ "$#" -eq 0 ]
then
	usage "Arguments missing"
	exit 1
fi

if [ -z "$BIN" -a -z "$ELF" ]; then
	usage "Either Input bin file or ELF file to sign"
	exit 1
fi

# Generate random key if user doesn't provide a key
if [ -z "$KEY" ]; then
	gen_key
fi

case "$CORE" in
     "a53_cl0_c0")
     ;;
     "a53_cl0_c1")
     ;;
     "a53_cl0_c2")
     ;;
     "a53_cl0_c3")
     ;;
     "hsm0")
     ;;
     "mcu_m4fss0_c0")
     ;;
     "r5_cl0_c0")
     ;;
     "mcu_r5_cl0_c0")
     ;;
     "main_r5_cl0_c0")
     ;;
     "c7_cl0_c0")
     ;;
     "c7_cl1_c0")
     ;;
     *)
       echo "unsupported core"
       exit 1
esac

if [ $enc_valid -eq 1 ]; then
	image_encrypt
	BIN=$ENC_BIN
fi

BOOTCORE=${core_ids["$CORE"]}

AUTH_CODE=$(( ((COPY_AS_HOST << 8) | (AUTH_TYPE)) & 0xFFFF ))
AUTH_TYPE=$AUTH_CODE

SHA_OID=${sha_oids["$SHA"]}
SHA_VAL=`openssl dgst -$SHA -hex $BIN | sed -e "s/^.*= //g"`
BIN_SIZE=`cat $BIN | wc -c`
ADDR=`printf "%08x" $LOADADDR`

BOOTCORE_OPTS_VER=$(printf "%01x" 1)
BOOTCORE_OPTS_SETFLAG=$(printf "%08x" 0)
BOOTCORE_OPTS_CLRFLAG=$(printf "%08x" 0x100)
BOOTCORE_OPTS="0x$BOOTCORE_OPTS_VER$BOOTCORE_OPTS_SETFLAG$BOOTCORE_OPTS_CLRFLAG"

# Generate firewall extension
gen_firewall_extension() {

# Check whether firewall 
if [ $FIREWALL_CONF_AVAIL -eq 1 ]; then

# Create a temporary file to store the firewall extension
FIREWALL_TEMPLATE_FILE=$(mktemp tmp.FILE.XXX)
FIREWALL_TEMPLATE_FILE_1=$(mktemp tmp.FILE.XXX)

# Get the number of regions
NUM_FWL_REGIONS=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( len(json.load(sys.stdin)) )"`

# Add the field that contains the total number of regions
cat << 'EOF1' > "$FIREWALL_TEMPLATE_FILE_1"
[ firewall ]
numFirewallRegions = INTEGER:NUM_FWL_REGIONS
EOF1
sed -e "s/NUM_FWL_REGIONS/$NUM_FWL_REGIONS/" "$FIREWALL_TEMPLATE_FILE_1" >> "$FIREWALL_TEMPLATE_FILE"

# Iterate over each firewall region structure
i=0
while [ "$i" -lt "$NUM_FWL_REGIONS" ]
do

FIREWALL_ID=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['firewall_id'] )"`
REGION=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['region'] )"`
CONTROL=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['control'] )"`
N_PERMISSION_REGS=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( len(json.load(sys.stdin)[$i]['permissions']) )"`
START_ADDRESS=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['start_address'] )"`
END_ADDRESS=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['end_address'] )"`
START_ADDRESS=$(printf "%08x" $START_ADDRESS)
END_ADDRESS=$(printf "%08x" $END_ADDRESS)

# Add a block for the firewall region structure
cat << 'EOF2' > "$FIREWALL_TEMPLATE_FILE_1"
firewallID = INTEGER:FIREWALL_ID
region = INTEGER:REGION
control = INTEGER:CONTROL
nPermissionRegs = INTEGER:N_PERMISSION_REGS
EOF2
sed 	-e "s/firewallID/firewallID$i/" \
	-e "s/FIREWALL_ID/$FIREWALL_ID/" \
	-e "s/region/region$i/" \
	-e "s/REGION/$REGION/" \
	-e "s/control/control$i/" \
	-e "s/CONTROL/$CONTROL/" \
	-e "s/nPermissionRegs/nPermissionRegs$i/" \
	-e "s/N_PERMISSION_REGS/$N_PERMISSION_REGS/" \
	"$FIREWALL_TEMPLATE_FILE_1" >> "$FIREWALL_TEMPLATE_FILE"

# Iterate over all the permission register values
j=0
while [ "$j" -lt "$N_PERMISSION_REGS" ]
do

PERMISSION=`cat $FIREWALL_CONF_FILE | python3 -c "import sys, json; print( json.load(sys.stdin)[$i]['permissions'][$j] )"`

cat << 'EOF3' > "$FIREWALL_TEMPLATE_FILE_1"
permission = INTEGER:PERMISSION
EOF3
sed 	-e "s/permission/permission$i$j/" \
	-e "s/PERMISSION/$PERMISSION/" \
	"$FIREWALL_TEMPLATE_FILE_1" >> "$FIREWALL_TEMPLATE_FILE"

j=$((j+1))

done

# Add the start and end addresses
cat << 'EOF4' > "$FIREWALL_TEMPLATE_FILE_1"
startAddress = FORMAT:HEX,OCT:START_ADDRESS
endAddress = FORMAT:HEX,OCT:END_ADDRESS
EOF4
sed 	-e "s/startAddress/startAddress$i/" \
	-e "s/endAddress/endAddress$i/" \
	-e "s/START_ADDRESS/$START_ADDRESS/" \
	-e "s/END_ADDRESS/$END_ADDRESS/" \
	"$FIREWALL_TEMPLATE_FILE_1" >> "$FIREWALL_TEMPLATE_FILE"

i=$((i+1))

done

# Store the extension in the FIREWALL_EXTENSION variable
FIREWALL_EXTENSION="$(cat $FIREWALL_TEMPLATE_FILE)"

# Delete the temporary extension template file
rm "$FIREWALL_TEMPLATE_FILE"
rm "$FIREWALL_TEMPLATE_FILE_1"

fi
}

# Shell function to generate x509 Template
gen_template() {
cat << 'EOF' > "$X509_TEMPLATE"
[ req ]
distinguished_name     = req_distinguished_name
x509_extensions        = v3_ca
prompt                 = no

dirstring_type = nobmp

[ req_distinguished_name ]
C                      = US
ST                     = SC
L                      = New York
O                      = Texas Instruments., Inc.
OU                     = DSP
CN                     = Albert
emailAddress           = Albert@gt.ti.com

[ v3_ca ]
basicConstraints = CA:true
1.3.6.1.4.1.294.1.33 = ASN1:SEQUENCE:sysfw_boot_seq
1.3.6.1.4.1.294.1.34 = ASN1:SEQUENCE:sysfw_image_integrity
1.3.6.1.4.1.294.1.35 = ASN1:SEQUENCE:sysfw_image_load
1.3.6.1.4.1.294.1.3 = ASN1:SEQUENCE:swrv
1.3.6.1.4.1.294.1.4 = ASN1:SEQUENCE:encryption
1.3.6.1.4.1.294.1.37 = ASN1:SEQUENCE:firewall
1.3.6.1.4.1.294.1.40 = ASN1:SEQUENCE:encryption_extended
1.3.6.1.4.1.294.1.38 = ASN1:SEQUENCE:key_info 
1.3.6.1.4.1.294.1.39 = ASN1:SEQUENCE:keyring_info

[ sysfw_image_integrity ]
shaType = OID:TEST_IMAGE_SHA_OID
shaValue = FORMAT:HEX,OCT:TEST_IMAGE_SHA_VAL
imageSize = INTEGER:TEST_IMAGE_LENGTH

[ sysfw_image_load ]
destAddr = FORMAT:HEX,OCT:TEST_BOOT_ADDR
authInPlace = INTEGER:AUTH_TYPE

[ swrv ]
swrv = INTEGER:SWREV

EOF

# Generate the firewall extension if required
if [ "$FIREWALL_CONF_AVAIL" -eq 1 ]; then
	gen_firewall_extension
	echo "$FIREWALL_EXTENSION" | cat >> "$X509_TEMPLATE"
else
	sed -e '/firewall/d' -i "$X509_TEMPLATE"
fi

# Generate the key info extension if required
if [ "$KEY_INFO_CONF_AVAIL" -eq 1 ]; then
        cat << 'EOFKEY' >> "$X509_TEMPLATE"
[ key_info ]
auth_key_id =  INTEGER:AUTH_KEYRING_ID
enc_key_id  =  INTEGER:ENC_KEYRING_ID

EOFKEY
else
	sed -e '/key_info/d' -i "$X509_TEMPLATE"
fi

# Generate the keyring info extension if required
if [ "$KEYRING_INFO_CONF_AVAIL" -eq 1 ]; then
        cat << 'EOFNKEY' >> "$X509_TEMPLATE"
[ keyring_info ]
num_of_asym_keys =  INTEGER:NUM_ASYMM_KEYS
num_of_sym_keys =  INTEGER:NUM_SYMM_KEYS

EOFNKEY
else
	sed -e '/keyring_info/d' -i "$X509_TEMPLATE"
fi

#Remove sysfw_image_load extension if it's a MCELF image
if [ "$MCELF_CONF_AVAIL" -eq 1 ]; then
    sed -e '/ASN1:SEQUENCE:sysfw_image_load/d' -i "$X509_TEMPLATE"
	sed -i '/ sysfw_image_load /,/^$/d' "$X509_TEMPLATE"
fi


if [ "$NO_BOOT" -eq 0 ]; then
cat << 'EOF2' >> "$X509_TEMPLATE"
[ sysfw_boot_seq ]
bootCore = INTEGER:TEST_BOOT_CORE
configFlagsSet = INTEGER:0
configFlagsClear = INTEGER:0
resetVec = FORMAT:HEX,OCT:RESET_VECTOR
rsvdFldValid = FORMAT:HEX,OCT:0000
rsvd1 = INTEGER:0
rsvd2 = INTEGER:0
rsvd3 = INTEGER:0
EOF2
else
    sed -e '/sysfw_boot_seq/d' -i "$X509_TEMPLATE"
fi

if [ "$enc_valid" -eq 1 ]; then
        cat << 'EOFENC' >> "$X509_TEMPLATE"
[ encryption ]
initalVector  =  FORMAT:HEX,OCT:TEST_IMAGE_ENC_IV
randomString  =  FORMAT:HEX,OCT:TEST_IMAGE_ENC_RS
iterationCnt  =  INTEGER:TEST_IMAGE_KEY_DERIVE_INDEX
salt          =  FORMAT:HEX,OCT:TEST_IMAGE_KEY_DERIVE_SALT

[ encryption_extended ]
nPaddingBytes =  INTEGER:N_PADDING_BYTES
rsvd0 =  INTEGER:0
rsvd1 =  INTEGER:0
EOFENC

else
    sed -e '/encryption/d' -i "$X509_TEMPLATE"
    sed -e '/encryption_extended/d' -i "$X509_TEMPLATE"
fi
}

# Shell function to generate x509 certificate
gen_cert() {
	echo "Certificate being generated for core - $CORE:"
	echo "	LOADADDR = 0x$ADDR"
	echo "	IMAGE_SIZE = $BIN_SIZE"
	sed -e "s/TEST_IMAGE_LENGTH/$BIN_SIZE/"	\
		-e "s/TEST_IMAGE_SHA_OID/$SHA_OID/" \
		-e "s/TEST_IMAGE_SHA_VAL/$SHA_VAL/" \
		-e "s/SWREV/$SWREV/" \
		-e "s/AUTH_KEYRING_ID/$AUTH_KEYRING_ID/"\
		-e "s/ENC_KEYRING_ID/$ENC_KEYRING_ID/"\
		-e "s/NUM_ASYMM_KEYS/$NUM_ASYMM_KEYS/"\
		-e "s/NUM_SYMM_KEYS/$NUM_SYMM_KEYS/"\
		-e "s/TEST_BOOT_CORE_OPTS/$BOOTCORE_OPTS/" \
		-e "s/TEST_BOOT_CORE/$BOOTCORE/" \
		-e "s/TEST_BOOT_ADDR/$ADDR/" \
		-e "s/RESET_VECTOR/$ADDR/" \
		-e "s/AUTH_TYPE/$AUTH_TYPE/" \
		-e "s/TEST_IMAGE_ENC_IV/$ENC_IV_VAL/" \
		-e "s/TEST_IMAGE_ENC_RS/$ENC_RS_VAL/" \
		-e "s/TEST_IMAGE_KEY_DERIVE_INDEX/$ENC_KD_INDEX_VAL/" \
		-e "s/TEST_IMAGE_KEY_DERIVE_SALT/$ENC_KD_SALT_VAL/" \
		-e "s/N_PADDING_BYTES/$N_PADDING_BYTES/" \
		"$X509_TEMPLATE" > $TEMP_X509
	openssl req -new -x509 -key $KEY -nodes -outform DER -out $CERT -config $TEMP_X509 -$SHA
}

gen_template
gen_cert
mv "$CERT" "$OUTPUT"

rm -f "$TEMP_X509" "$X509_TEMPLATE"
rm -f "$ENC_IV" "$ENC_RS"
#rm -f "$OUTPUT.h"
#cat "$CERT" | xxd -i  > "$OUTPUT.h"
#echo "," >> "$OUTPUT.h"
#cat "$BIN" | xxd -i  >> "$OUTPUT.h"
#echo "SUCCESS: Image $OUTPUT generated."
#echo "SUCCESS: Header file $OUTPUT.h generated."
