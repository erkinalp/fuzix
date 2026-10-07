/*
 *	Olivetti M20 linker script for z8k-coff
 *
 *	Z8001 segmented addressing.  The linker uses PHYSICAL addresses
 *	(segment << 16 | offset), NOT CPU register encoding.
 *	See ~/Projects/documents/z8k-coff-linker-segment-encoding.md
 *
 *	Layout:
 *	  Segment 2: Kernel data, BSS, stacks, udata
 *	    0x0000-0x003F  BIOS workspace (reserved)
 *	    0x0100-0x017F  PSAP (interrupt/trap vectors)
 *	    0x0200+        Kernel data, BSS, stacks
 *
 *	  Segment B: Kernel code (text + rodata)
 *	    0x0000+        Kernel code
 *
 *	Physical RAM (no overlaps between these two segments):
 *	  Seg 2 -> DRAM0 0x14000-0x1FFFF + DRAM1 0x00000 (64 KB)
 *	  Seg B -> DRAM1 0x14000-0x1FFFF + DRAM2 0x00000 (64 KB)
 */

OUTPUT_FORMAT("coff-z8k")
OUTPUT_ARCH(z8001)

STARTUP(crt0.o)

SECTIONS
{
  /* Kernel code in segment B */
  .text 0xB0000 :
  {
    CREATE_OBJECT_SYMBOLS
    *(.text .text.*)
    *(.rodata .rodata.*)

    . = ALIGN(0x2);
    _etext = .;
  }

  /* Kernel data in segment 2, starting at 0x0200 (after BIOS + PSAP) */
  .data 0x20200 :
  {
    _data = .;
    *(.data .data.*)
    _edata = .;
  }

  .bss :
  {
    . = ALIGN(0x2);
    __bss_start = .;
    *(.bss .bss.*)
    *(COMMON)
    _end = ALIGN(0x2);
    __end = _end;
  }
}
