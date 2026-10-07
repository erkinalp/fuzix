#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.common
;
;	On entry the bootloader has put the banker into the
;	kernel map and loaded us at 0x100 (it's at 0x0)
;
start:
	ld	sp, kstack_top
	ld	a,0xE0
	; Unmap I/O space as it may have BSS over it
	out	(0xC0),a
	; Zero the BSS
	ld 	hl, __bss
	ld 	de, __bss + 1
	ld 	bc, __bss_size - 1
	ld	(hl), 0
	ldir
	ld	hl, __buffers
	ld	de, __buffers + 1
	ld	bc, __buffers_size - 1
	ld	(hl), 0
	ldir
	call	init_early
	call	init_hardware
	call	_vtinit
	call	_fuzix_main
	di
stop:	halt
	jr	stop

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.buffers

	.export _bufpool
_bufpool:
	.ds	BUFSIZE * NBUFS

