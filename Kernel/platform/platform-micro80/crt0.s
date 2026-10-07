# 1 "crt0.S"
;
;	We are loaded from CP/M at the moment
;
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes @ 0xC000
Z80_TYPE		.equ	0	; CMOS

Z80_MMU_HOOKS		.equ 0

CONFIG_SWAP		.equ 1

PROGBASE		.equ	0x1000
PROGLOAD		.equ	0x1000

; Mnemonics for I/O ports etc

; Z80 CTC ports
CTC_CH0		.equ	0x10	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x11	; CTC channel 1 (periodic interrupts)
CTC_CH2		.equ	0x12	; CTC channel 2
CTC_CH3		.equ	0x13	; CTC channel 3


SIOA_D		.equ	0x18
SIOA_C		.equ	0x19
SIOB_D		.equ	0x1A
SIOB_C		.equ	0x1B
RTS_LOW		.equ	0xEA

PIOA_D		.equ	0x1C
PIOA_C		.equ	0x1D
PIOB_D		.equ	0x1E
PIOB_C		.equ	0x1F
# 6 "crt0.S"
;
;	We don't want our image packed
;
		.code
;
;	Runs from 0x0100
;
		di

		ld sp, kstack_top
		; Zero the data area
		ld hl, __bss
		ld de, __bss + 1
		ld bc, __bss_size - 1
		ld (hl), 0
		ldir
		; Zero buffers area
		ld hl, __buffers
		ld de, __buffers + 1
		ld bc, __buffers_size - 1
		ld (hl), 0
		ldir

        	; Hardware setup
	        call init_hardware

	        ; Call the C main routine
	        call _fuzix_main
	        ; fuzix_main() shouldn't return, but if it does...
	        di
stop:		halt
		jr stop
