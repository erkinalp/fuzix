# 1 "crt0.S"
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes.
Z80_TYPE		.equ	0	; CMOS
U_DATA_STASH		.equ	0x7E00

Z80_MMU_HOOKS		.equ 0

CONFIG_SWAP		.equ 0

PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Mnemonics for I/O ports etc

CONSOLE_RATE		.equ	9600

CPU_CLOCK_KHZ		.equ	10000

; Base address of SIO/2 chip 0x30

SIOA_D		.equ	0x30
SIOB_D		.equ	0x31
SIOA_C		.equ	0x32
SIOB_C		.equ	0x33

; Z80 CTC ports
CTC_CH0		.equ	0x40	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x41	; CTC channel 1
CTC_CH2		.equ	0x42	; CTC channel 2
CTC_CH3		.equ	0x43	; CTC channel 3
# 3 "crt0.S"
	; Entered with bank = 0 from the bootstrap logic
	.code

	jp start
	.word 0x10AE

start:
	ld sp, #kstack_top

	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl),0
	ldir

	; FIXME: do we ened this
	; Zero buffers area
	ld hl, __buffers
	ld de, __buffers + 1
	ld bc, __buffers_size - 1
	ld (hl), 0
	ldir

	call init_hardware
	call _fuzix_main
	; Should never return
	di
stop:	halt
	jr stop

	.abs
	.org 0xFD00
	.export	_vectors
_vectors:
	.ds	256
