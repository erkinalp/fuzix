# 1 "crt0.S"
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

; We stick it straight after the tag
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256 @ FE00

U_DATA_STASH		    .equ 0xFE00	      ; FE00-FFFF

PROGBASE		    .equ 0x4000
PROGLOAD		    .equ 0x4000

NBUFS			    .equ 5

BANK_BITS		    .equ 0x18		; Spectrum ROM select
						; Video high
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 27 "crt0.S"
;	We are run from 0x0000
;	On entry we have main memory mapped, DIVMMC bank 0 mapped over
;	the ROM space and the top 16K is an undefined bank. SP is not
;	valid, interrupts are off.
;

	.abs
	.org	0

	; This first chunk of this gets overwritten by vectors
rst0:
	jp	null_handler
	jp	go
	nop
	nop
rst8:
	.ds	8
rst10:
	.ds	8
rst18:
	.ds	8
rst20:
	.ds	8
rst28:	
	.ds	8
rst30:	
	.ds	8
rst38:	
	jp	interrupt_handler
	.ds	5
	
	.ds	0x26
	jp	nmi_handler

	.export	go
go:
	; On entry we are in ZX128 made we have the mapping as
	; ROM/5/2/? and screen in 7. (5/8/? on systens with bank 2 not
	; shared..
	; Wipe screen with test pattern
	ld	bc, 0x7ffd
	ld	a, 0x0F
	out	(c), a
	ld	hl, 0xC000
	ld	de, 0xC001
	ld	bc, 0x3FFF
	ld	(hl), 0xAA
	ldir

	; We are living in the DIVMMC mapping and we now need to fix the
	; top mapping to be 3 with screen in 7
	ld	bc, 0x7ffd
	ld	a, 0x0B
	out	(c), a

	; Hires mode
	ld	a, 0x3E
	out	(0xFF), a

	;  We need to wipe the BSS but the rest of the job is done.

	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir
	ld	hl, __buffers
	ld	de, __buffers + 1
	ld	bc, __buffers_size - 1
	ld	(hl), 0
	ldir

	jp	boot

	.code

boot:
        ld	sp, kstack_top

        ; Configure memory map
	push	af
        call	init_early
	pop	af

        ; Hardware setup
	push	af
        call	init_hardware
	pop	af

        ; Call the C main routine
	push	af
        call	_fuzix_main
	pop	af
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr	stop

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool
	.buffers

_bufpool:
	.ds	520  * NBUFS
