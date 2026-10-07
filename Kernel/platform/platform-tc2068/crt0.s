# 1 "crt0.S"
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

; We stick it straight after the tag
U_DATA                      .equ 0x0080       ; (this is struct u_data from kernel.h)
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256+256 bytes.

Z80_TYPE		    .equ 1

PROGBASE		    .equ 0x7800
PROGLOAD		    .equ 0x7800

NBUFS			    .equ 5

Z80_MMU_HOOKS		    .equ 0
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 4 "crt0.S"
	;
        ; startup code
	;
	; We loaded the rest of the kernel from disk and jumped here
	;

	.code

	.export	_start

_start:
        di

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

        ld	sp, kstack_top

        ; Configure memory map
        call	init_early

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr	stop

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.buffers
	.export _bufpool

_bufpool:
	.ds 520  * NBUFS

; Force pad the binary

	.abs
	.org	0xFFFF

	.byte	0
