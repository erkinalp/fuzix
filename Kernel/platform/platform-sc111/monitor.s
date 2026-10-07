# 1 "monitor.S"
; 2015-01-17 William R Sowerbutts
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

; Move down to 0xF600 to fit the monitor in
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256 bytes @ F800

OS_BANK                     .equ 0x00         ; value from include/kernel.h

; Memory layout
FIRST_RAM_BANK              .equ 0x80         ; low 512K of physical memory is ROM
Z180_IO_BASE                .equ 0xC0

; Use standard clock for the SC111
USE_FANCY_MONITOR           .equ 1            ; disabling this saves around approx 0.5KB
CPU_CLOCK_KHZ               .equ 18432        ; 18.432MHz * 1
TICKSPERSEC                 .equ 40           ; timer interrupt rate (Hz)
TCR_CLOCK		    .equ 23040

PROGBASE		    .equ 0x0000
PROGLOAD		    .equ 0x0100
# 5 "monitor.S"
	.export _plt_monitor
	.export _plt_reboot
# 19
	.common
_plt_monitor:  di
	call outnewline
	; just dump a few words from the stack
	ld b, 50
stacknext:
	pop hl
	call outhl
	ld a, #' '
	call outchar
	djnz stacknext
	halt


_plt_reboot:	; TODO
	jr _plt_monitor
