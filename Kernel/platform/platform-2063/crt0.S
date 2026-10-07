#include "kernelu.def"

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
