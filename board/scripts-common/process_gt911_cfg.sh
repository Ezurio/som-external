#!/bin/sh

set -e

# Script to process gt911_cfg.hex: convert to bin, calculate 8-bit checksum, and update the file
# Usage: ./process_gt911_cfg.sh <hex_file>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <hex_file>"
    exit 1
fi

HEX_FILE="$1"
BIN_FILE="${HEX_FILE%.hex}.bin"

# Step 1: Convert hex to binary
echo "Converting $HEX_FILE to binary..."
xxd -r "$HEX_FILE" > "$BIN_FILE"

# Step 2: Get file size and calculate raw_cfg_len
FILE_SIZE=$(stat -c%s "$BIN_FILE")
RAW_CFG_LEN=$((FILE_SIZE - 2))

echo "File size: $FILE_SIZE bytes, raw config length: $RAW_CFG_LEN bytes"

# Step 3: Calculate 8-bit checksum
echo "Calculating 8-bit checksum..."
SUM=$(hexdump -v -n $RAW_CFG_LEN -e '1/1 "%u "' "$BIN_FILE" | \
    awk '{sum=0; for(i=1; i<=NF; i++) sum+=$i; print sum}')
CHECKSUM=$(( (~SUM + 1) & 0xFF ))

printf "Checksum: %02X\n" $CHECKSUM

# Step 4: Update the bin file with checksum and config_fresh
echo "Updating $BIN_FILE with checksum..."
printf "%02X 01\n" $CHECKSUM | xxd -r -p | \
    dd of="$BIN_FILE" bs=1 seek=$RAW_CFG_LEN conv=notrunc status=none

echo "Done. Updated $BIN_FILE"
