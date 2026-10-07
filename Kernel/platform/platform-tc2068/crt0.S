#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

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
	.ds BUFSIZE * NBUFS

; Force pad the binary

	.abs
	.org	0xFFFF

	.byte	0
