#!/usr/bin/env python3
"""Fix the a.out header in a FUZIX Z8001 flat binary.

Patches the header fields (a_text, a_data, a_entry) based on the
actual binary layout. The header is the first 64 bytes.
"""

import struct
import sys

HEADER_SIZE = 64
MIDMAG = 0x03B00108  # MID_FUZIXZ8000 | NMAGIC
ENTRY = 0x0020       # code at text[0] → loaded at u_codebase + 0x20
STACKSIZE = 0x0400   # 1024 bytes

def main():
    path = sys.argv[1]
    with open(path, 'rb') as f:
        d = bytearray(f.read())

    total = len(d) - HEADER_SIZE

    # The binary has: [header 64] [text] [data]
    # With our linker script, .rodata goes into .data section.
    # Find the data section by looking for the first non-code byte.
    # For simplicity, treat everything as text (no data section).
    a_text = total
    a_data = 0
    a_bss = 0

    # Build header
    struct.pack_into('>I', d, 0, MIDMAG)
    struct.pack_into('>I', d, 4, a_text)
    struct.pack_into('>I', d, 8, a_data)
    struct.pack_into('>I', d, 12, a_bss)
    struct.pack_into('>I', d, 16, 0)         # a_syms
    struct.pack_into('>I', d, 20, ENTRY)     # a_entry
    struct.pack_into('>I', d, 24, 0)         # a_trsize
    struct.pack_into('>I', d, 28, 0)         # a_drsize
    struct.pack_into('>I', d, 32, STACKSIZE) # stacksize

    with open(path, 'wb') as f:
        f.write(d)

    print(f"Fixed {path}: size={len(d)} a_text=0x{a_text:x} a_entry=0x{ENTRY:x}")
    print(f"  code loaded: {a_text - 0x20} bytes at u_codebase+0x20")

if __name__ == '__main__':
    main()
