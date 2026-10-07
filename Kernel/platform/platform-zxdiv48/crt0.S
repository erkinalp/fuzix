#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	;
        ; startup code. Called with most stuff indeterminate but overlay 1
        ; mapped. On entry A is the machine type.
	; A = 0		DivIDE plus
	; A = 1		ZXCF 512K+ (we need to do sizing later)
	;

	.overlay1

	.export _go	; should be at 0x0080

_go:

        di

	;  We need to wipe the BSS but the rest of the job is done.

	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir

	; Debug trace on
	ld	bc,0x50FD
	out	(c),b

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

	.common

	.export stub
	.export stub_end
stub:
	.ds	540
stub_end:

	.overlay4
;
;	Buffers live with overlay 4 where we have a little bit of room
;	We link them first at 0x80
;
	.export	bufdata
bufdata:
	.ds 512 * NBUFS

; Hack so they don't get turned into a stub reference by the bankman

	.abs
	.org	0x80
	.export	_bufdata

_bufdata:
