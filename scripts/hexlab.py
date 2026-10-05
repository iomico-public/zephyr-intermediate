#!/usr/bin/env python3
import argparse
import os

from intelhex import IntelHex

# TF-M flash_layout.h for AN521; BL2 uses these, not Zephyr DT partitions.
NS_PRIMARY = 0x00100000
NS_SECONDARY = 0x00200000
NS_SECONDARY_END = 0x00280000

# MCUboot image trailer: magic occupies the last 16 bytes of the slot,
# image_ok sits one 8-byte-aligned field below it.
BOOT_MAGIC = bytes([0x77, 0xC2, 0x95, 0xF3, 0x60, 0xD2, 0xEF, 0x7F,
                    0x35, 0x52, 0x50, 0x0F, 0x2C, 0xB6, 0x79, 0x80])
MAGIC_ADDR = NS_SECONDARY_END - len(BOOT_MAGIC)
IMAGE_OK_ADDR = (MAGIC_ADDR - 8) & ~0x7


# Save ih to path, creating the directory if needed.
def write(ih, path):
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    ih.write_hex_file(path)


# Flip every bit of one byte.
def tamper(args):
    ih = IntelHex(args.source)
    before = ih[args.address]
    ih[args.address] = before ^ 0xFF
    write(ih, args.output)
    print(f"tampered 0x{args.address:08x}: 0x{before:02x} -> 0x{ih[args.address]:02x}")


# Copy a signed image into the secondary slot and mark it pending.
def stage_upgrade(args):
    base = IntelHex(args.primary)
    payload = IntelHex(args.payload)
    payload_start = payload.minaddr()
    for address in payload.addresses():
        base[NS_SECONDARY + (address - payload_start)] = payload[address]
    for index, value in enumerate(BOOT_MAGIC):
        base[MAGIC_ADDR + index] = value
    write(base, args.output)
    print(f"staged 0x{payload_start:08x} ({len(payload.addresses())} bytes) at 0x{NS_SECONDARY:08x}, "
          f"magic at 0x{MAGIC_ADDR:08x}, no image_ok")


# Confirm the staged image so BL2 performs the swap.
def set_image_ok(args):
    ih = IntelHex(args.source)
    ih[IMAGE_OK_ADDR] = 0x01
    write(ih, args.output)
    print(f"image_ok = 0x01 at 0x{IMAGE_OK_ADDR:08x}")


# Parse the subcommand and dispatch to it.
def main():
    parser = argparse.ArgumentParser(description="AN521 secure-boot image surgery")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("tamper", help="flip one byte in the NS payload")
    p.add_argument("source")
    p.add_argument("output")
    p.add_argument("--address", type=lambda v: int(v, 0), default=NS_PRIMARY + 0x2000)
    p.set_defaults(func=tamper)

    p = sub.add_parser("stage-upgrade", help="place a signed NS image in the secondary slot")
    p.add_argument("primary")
    p.add_argument("payload")
    p.add_argument("output")
    p.set_defaults(func=stage_upgrade)

    p = sub.add_parser("set-image-ok", help="write image_ok so the swap is taken")
    p.add_argument("source")
    p.add_argument("output")
    p.set_defaults(func=set_image_ok)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
