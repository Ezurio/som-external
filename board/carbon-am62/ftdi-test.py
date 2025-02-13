#! /usr/bin/env python3

# WBx3 board switch control script

import ftdi1 as ftdi
import sys

def exit_with_error(context, message, error_code=1):
    print(message)
    if context:
        ftdi.free(context)
    sys.exit(error_code)

context = ftdi.new()

# try to open an ftdi 0x6010 or 0x6001
ret = ftdi.usb_open_desc(context, 0x0403, 0x6015, 'FT240X USB FIFO', None)
if ret < 0:
    exit_with_error(None, f"ftdi.usb_open_desc(): {ret}")

ret = ftdi.set_bitmode(context, 0xff, ftdi.BITMODE_BITBANG)
if ret < 0:
    exit_with_error(context, f"ftdi.set_bitmode(): {ret}")

if len(sys.argv) > 1:
    try:
        data = bytes.fromhex(sys.argv[1])
    except ValueError:
        exit_with_error(context, "Invalid hex string provided.")
else:
    data = b'\x00'

print("Data to be written (hex):", ' '.join([f'{x:02x}' for x in data]))

ret = ftdi.write_data(context, data)
if ret < 0:
    exit_with_error(context, f"ftdi.write_data(): {ret}")

ftdi.free(context)
