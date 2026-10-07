#!/usr/bin/env python3
"""Build an M20 PCOS-bootable hard disk image for FUZIX.

Creates an HD image with:
  Sector 0:   Geometry/boot record (PCOS compatible)
  Sector 32:  VDB/extent record
  Sector 33:  Bootloader SAV file
  Sector 64:  Kernel load header (16 bytes)
  Sector 65+: Kernel text section (raw binary)
  Sector N:   Kernel data section (raw binary)
  Sector M+:  FUZIX filesystem (if provided)

The bootloader reads the header at sector 64 to determine where to
load the text and data sections and where to jump.

Header format (16 bytes, big-endian):
  +0x00: text segment  (word, e.g. 0x8B00 for segment B)
  +0x02: text offset   (word, e.g. 0x0000)
  +0x04: text sectors  (word, number of 256-byte sectors)
  +0x06: data segment  (word, e.g. 0x8200 for segment 2)
  +0x08: data offset   (word, e.g. 0x0200)
  +0x0A: data sectors  (word, number of 256-byte sectors)
  +0x0C: entry segment (word, e.g. 0x8B00)
  +0x0E: entry offset  (word, e.g. 0x0000)

Usage: python3 mkm20hd.py <bootloader.bin> <text.bin> <data.bin> <output.img> [filesystem.img]
"""

import struct
import sys
import math

SECTOR_SIZE = 256
TOTAL_SECTORS = 34560  # 6 heads * 180 cyl * 32 sec/track

# HD image layout
GEOM_SECTOR = 0
VDB_SECTOR = 32
BOOT_SECTOR = 33
HDR_SECTOR = 64
TEXT_SECTOR = 65       # text starts right after header

# Kernel segment addresses (Z8001 segmented, high bit set)
TEXT_SEG = 0x8B00      # Segment B
TEXT_OFF = 0x0000
DATA_SEG = 0x8200      # Segment 2
DATA_OFF = 0x0200      # After BIOS workspace + PSAP
ENTRY_SEG = 0x8B00     # Entry point = start of text
ENTRY_OFF = 0x0000


def sectors_needed(size):
    """Round up to number of 256-byte sectors."""
    return math.ceil(size / SECTOR_SIZE)


def make_geometry_sector():
    """Sector 0: geometry/boot record (from working PCOS image)."""
    sector = bytearray(SECTOR_SIZE)
    pcos_sec0 = bytes([
        0x02, 0x00, 0x00, 0xB3, 0x06, 0x20, 0x01, 0x00,
        0x00, 0x3C, 0x00, 0x38, 0x00, 0x88, 0x1E, 0x00,
        0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x01, 0x00, 0xB2, 0x00, 0x00, 0x00, 0xB2,
        0x00, 0x00, 0x00, 0xB2, 0x00, 0x00, 0x00, 0xB2,
        0x00, 0x00, 0x00, 0x20, 0x50, 0x43, 0x4F, 0x53,
        0x00, 0x00, 0x00, 0x13, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x01, 0xFF, 0xFF, 0x02, 0x00, 0x06, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    ])
    sector[:len(pcos_sec0)] = pcos_sec0
    return sector


def make_vdb_sector(code_len):
    """VDB/extent record for bootloader SAV."""
    SAV_HEADER_SIZE = 0x18
    sector = bytearray(SECTOR_SIZE)
    expcount = (SAV_HEADER_SIZE + code_len) & 0xFF
    seccount = 1
    seccount_adj = seccount - 1 if expcount != 0 else seccount
    validation = ((seccount_adj >> 8) << 16) | ((seccount_adj & 0xFF) << 8) | expcount
    struct.pack_into('>I', sector, 0x00, validation)
    struct.pack_into('>H', sector, 0x04, 1)
    struct.pack_into('>HHH', sector, 0x1A, BOOT_SECTOR, 1, 0)
    return sector


def make_sav_sector(code):
    """SAV absolute file wrapping the bootloader binary."""
    max_code = SECTOR_SIZE - 24
    if len(code) > max_code:
        print(f"Error: bootloader binary ({len(code)} bytes) exceeds "
              f"SAV sector capacity ({max_code} bytes)", file=sys.stderr)
        sys.exit(1)
    if len(code) % 2:
        code = code + b'\x00'
    sav = bytearray(SECTOR_SIZE)
    sav[0:2] = b'\x01\x01'
    sav[2:12] = b'FUZX\x00\x00\x00\x00\x00\x00'
    struct.pack_into('>HH', sav, 0x0C, 0x8600, 0x0000)
    struct.pack_into('>H', sav, 0x10, 1)
    struct.pack_into('>HH', sav, 0x12, 0x8600, 0x0000)
    struct.pack_into('>H', sav, 0x16, len(code) // 2)
    sav[0x18:0x18 + len(code)] = code
    return sav


def make_kernel_header(text_sectors, data_sectors):
    """16-byte kernel load header."""
    hdr = bytearray(SECTOR_SIZE)
    struct.pack_into('>HH', hdr, 0x00, TEXT_SEG, TEXT_OFF)      # text seg:off
    struct.pack_into('>H',  hdr, 0x04, text_sectors)            # text sector count
    struct.pack_into('>HH', hdr, 0x06, DATA_SEG, DATA_OFF)     # data seg:off
    struct.pack_into('>H',  hdr, 0x0A, data_sectors)            # data sector count
    struct.pack_into('>HH', hdr, 0x0C, ENTRY_SEG, ENTRY_OFF)   # entry point
    return hdr


def main():
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <bootloader.bin> <text.bin> <data.bin> <output.img> [filesystem.img]",
              file=sys.stderr)
        sys.exit(1)

    bootloader_path = sys.argv[1]
    text_path = sys.argv[2]
    data_path = sys.argv[3]
    output_path = sys.argv[4]
    fs_path = sys.argv[5] if len(sys.argv) > 5 else None

    with open(bootloader_path, 'rb') as f:
        bootloader_bin = f.read()
    with open(text_path, 'rb') as f:
        text_bin = f.read()
    with open(data_path, 'rb') as f:
        data_bin = f.read()

    text_sectors = sectors_needed(len(text_bin))
    data_sectors = sectors_needed(len(data_bin))
    data_start_sector = TEXT_SECTOR + text_sectors
    fs_start_sector = data_start_sector + data_sectors
    # Align filesystem to a nice boundary
    fs_start_sector = ((fs_start_sector + 63) // 64) * 64

    # Check sizes
    if len(text_bin) > 65536:
        print(f"Error: text section ({len(text_bin)} bytes) exceeds 64 KB", file=sys.stderr)
        sys.exit(1)
    if len(data_bin) > 65536:
        print(f"Error: data section ({len(data_bin)} bytes) exceeds 64 KB", file=sys.stderr)
        sys.exit(1)

    # Build image
    img = bytearray(TOTAL_SECTORS * SECTOR_SIZE)

    # Sector 0: geometry
    img[GEOM_SECTOR * SECTOR_SIZE:(GEOM_SECTOR + 1) * SECTOR_SIZE] = make_geometry_sector()

    # Sector 32: VDB
    padded_len = len(bootloader_bin) + (len(bootloader_bin) % 2)
    img[VDB_SECTOR * SECTOR_SIZE:(VDB_SECTOR + 1) * SECTOR_SIZE] = make_vdb_sector(padded_len)

    # Sector 33: bootloader SAV
    img[BOOT_SECTOR * SECTOR_SIZE:(BOOT_SECTOR + 1) * SECTOR_SIZE] = make_sav_sector(bootloader_bin)

    # Sector 64: kernel header
    img[HDR_SECTOR * SECTOR_SIZE:(HDR_SECTOR + 1) * SECTOR_SIZE] = make_kernel_header(text_sectors, data_sectors)

    # Sector 65+: text section
    off = TEXT_SECTOR * SECTOR_SIZE
    img[off:off + len(text_bin)] = text_bin

    # After text: data section
    off = data_start_sector * SECTOR_SIZE
    img[off:off + len(data_bin)] = data_bin

    # Optional: filesystem
    if fs_path:
        with open(fs_path, 'rb') as f:
            fs_bin = f.read()
        off = fs_start_sector * SECTOR_SIZE
        if off + len(fs_bin) > len(img):
            print(f"Error: filesystem image too large for HD", file=sys.stderr)
            sys.exit(1)
        img[off:off + len(fs_bin)] = fs_bin

    with open(output_path, 'wb') as f:
        f.write(img)

    print(f"HD image: {output_path} ({len(img)} bytes, {TOTAL_SECTORS} sectors)")
    print(f"  Geometry record:  sector {GEOM_SECTOR}")
    print(f"  VDB/extent:       sector {VDB_SECTOR}")
    print(f"  Bootloader SAV:   sector {BOOT_SECTOR} ({len(bootloader_bin)} bytes code)")
    print(f"  Kernel header:    sector {HDR_SECTOR}")
    print(f"  Text section:     sector {TEXT_SECTOR}-{TEXT_SECTOR + text_sectors - 1} "
          f"({len(text_bin)} bytes, {text_sectors} sectors) -> <{TEXT_SEG>>8:X}>:{TEXT_OFF:04X}")
    print(f"  Data section:     sector {data_start_sector}-{data_start_sector + data_sectors - 1} "
          f"({len(data_bin)} bytes, {data_sectors} sectors) -> <{DATA_SEG>>8:X}>:{DATA_OFF:04X}")
    print(f"  Entry point:      <{ENTRY_SEG>>8:X}>:{ENTRY_OFF:04X}")
    if fs_path:
        print(f"  Filesystem:       sector {fs_start_sector}+ ({len(fs_bin)} bytes)")
    else:
        print(f"  Filesystem:       not included (would start at sector {fs_start_sector})")


if __name__ == '__main__':
    main()
