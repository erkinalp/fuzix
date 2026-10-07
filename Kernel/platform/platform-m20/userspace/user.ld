OUTPUT_FORMAT("coff-z8k")
OUTPUT_ARCH(z8001)
SECTIONS
{
  .text 0 : { *(.text .text.*) }
  .data : { *(.data .rodata .rodata.*) }
  .bss : { *(.bss) *(COMMON) }
}
