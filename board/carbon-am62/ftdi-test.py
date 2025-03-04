#! /usr/bin/env python3

# WBx3 board switch control script

import sys
import usb

if len(sys.argv) > 1:
    try:
        data = bytes.fromhex(sys.argv[1])
    except ValueError:
        print("Invalid hex string provided.")
        sys.exit(1)
else:
    data = b'\xcc'

if len(sys.argv) > 2:
    try:
        data1 = int(sys.argv[2], 16)
    except ValueError:
        print("Invalid hex string provided.")
        sys.exit(1)
else:
    data1 = 0

data1 = (data1 & 0x0f) | 0x70

BITMODE_BITBANG = 0x01
BITMODE_CBUS = 0x20
SIO_SET_BITMODE_REQUEST = 0x0b

def ftdi_set_bitmode(dev, bitmask, bitmode):
    bmRequestType = usb.util.build_request_type(usb.util.CTRL_OUT,
                                                usb.util.CTRL_TYPE_VENDOR,
                                                usb.util.CTRL_RECIPIENT_DEVICE)

    wValue = bitmask | (bitmode << 8)
    dev.ctrl_transfer(bmRequestType, SIO_SET_BITMODE_REQUEST, wValue)

dev = usb.core.find(custom_match = \
        lambda d: \
            d.idVendor==0x0403 and
            d.idProduct==0x6015 and
            d.product=='FT240X USB FIFO')

if not dev:
    print("FT240X USB FIFO not found.")
    sys.exit(1)

# Remove ttyUSB for this device
dev.detach_kernel_driver(0)

#for config in dev:
#    for i in range(config.bNumInterfaces):
#        if dev.is_kernel_driver_active(i):
#            dev.detach_kernel_driver(i)

dev.set_configuration()

ftdi_set_bitmode(dev, 0xff, BITMODE_BITBANG)

dev.write(0x02, data)

dev1 = usb.core.find(custom_match = \
        lambda d: \
            d.idVendor==0x0403 and
            d.idProduct==0x6015 and
            d.product=='FT230X Basic UART')

if not dev1:
    print("FT230X Basic UART not found.")
    sys.exit(1)


ftdi_set_bitmode(dev1, data1, BITMODE_CBUS)
