# 1 "crt0.S"
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

; We stick it straight after the tag
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256@F000

Z80_TYPE		    .equ 1

PROGBASE		    .equ 0x0000
PROGLOAD		    .equ 0x0100

NBUFS			    .equ 5

Z80_MMU_HOOKS		    .equ 0
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 69 "crt0.S"
	;
        ; startup code
	;
	; We loaded the rest of the kernel from disk and jumped here
	;

	.code
	.export	_start

_start:

        di

        ld sp, kstack_top
	;
	; move the common memory where it belongs    
	ld hl, __bss
	ld de, __common
	ld bc, __common_size
	ldir

	; then the font
;	ld de, #__FONT
;	ld bc, #l__FONT
;	ldir

	; then the discard (backwards as will overlap)
	ld de, __discard
	ld bc, __discard_size-1
	ex de,hl
	add hl,bc
	ex de,hl
	add hl,bc
	lddr
	ldd

	; then zero the data area
	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl), #0
	ldir
	; and buffers
	ld hl, __buffers
	ld de, __buffers + 1
	ld bc, __buffers_size - 1
	ld (hl), #0
	ldir

        ; Configure memory map
        call init_early

        ; Hardware setup
        call init_hardware

        ; Call the C main routine
        call _fuzix_main
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr stop

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;
	.buffers

	.export _bufpool

_bufpool:
	.ds 520  * NBUFS
