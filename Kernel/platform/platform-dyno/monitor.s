# 1 "monitor.S"
; 2015-01-17 William R Sowerbutts
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE       .equ 0x200        ; 256+256 bytes @ F800

OS_BANK                 .equ 0x00         ; value from include/kernel.h

; Memory layout
FIRST_RAM_BANK          .equ 0x80         ; low 512K of physical memory is ROM/ECB window.
Z180_IO_BASE            .equ 0xC0

USE_FANCY_MONITOR       .equ 1            ; disabling this saves around approx 0.5KB
CPU_CLOCK_KHZ           .equ 18432        ; 18.432MHz * 1
Z180_TIMER_SCALE        .equ 20           ; CPU clocks per timer tick
TICKSPERSEC             .equ 40           ; timer interrupt rate (Hz)

PROGBASE		.equ 0x0000
PROGLOAD		.equ 0x0100



FDC_MSR			.equ	0x84
FDC_DATA		.equ	0x85
FDC_DOR			.equ	0x86
FDC_CCR			.equ	0x87
FDC_TC			.equ	0x86	  ; TC is a read



PPIDE_RD_LINE	.equ	0x40
PPIDE_WR_LINE	.equ	0x20
PPIDE_PPI_BUS_READ	.equ	0x92
PPIDE_PPI_BUS_WRITE	.equ	0x80

ppi_port_a	.equ	0x4C
ppi_port_b	.equ	0x4D
ppi_port_c	.equ	0x4E
ppi_control	.equ	0x4F

ppide_data	.equ	0x08
# 5 "monitor.S"
	.export _plt_monitor
	.export _plt_reboot
# 22
	.common

_plt_monitor:
	di
	call outnewline
	; just dump a few words from the stack
	ld b, #50
stacknext:
	pop hl
	call outhl
	ld a, #' '
	call outchar
	djnz stacknext
	halt

_plt_reboot:	; TODO
	jr _plt_monitor
