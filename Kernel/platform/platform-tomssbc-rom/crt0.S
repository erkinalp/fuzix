#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.export _go

	.discard
_go:
        di

	;  We need to wipe the BSS but the rest of the job is done.
	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl), 0
	ldir

        ld sp, kstack_top

        ; Configure memory map
	push af
        call init_early
	pop af

        ; Hardware setup
	push af
        call init_hardware
	pop af

	jp work

	.code
work:
        ; Call the C main routine
	push af
        call _fuzix_main
	pop af
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr stop

	.common

	.export stub
	.export stub_end
stub:
	.ds 550
stub_end:

	.buffers

	.export _bufpool
_bufpool:
	.ds BUFSIZE * NBUFS
