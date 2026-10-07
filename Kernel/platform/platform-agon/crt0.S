#include "kernelu.def"

	; Entered from MOS at 04:0000 in Z80 mode with MBASE = 04, MADL set
	.z180
	.code

	jp	start
	.ds	0x3D
	; MOS executable header at 0x40
	.ascii	"MOS"
	.byte	0			; version
	.byte	0			; Z80 mode
	.ds	0xBB

start:
	di
	.byte	0xED,0x7E		; rsmix

	; Internal RAM on at E000-FFFF of our bank. This is common memory
	ld	a,0x80
	out0	(RAM_CTL),a
	ld	a,KERNEL_BANK
	out0	(RAM_ADDR_U),a

	ld	sp, kstack_top

	; move the common memory where it belongs
	ld	hl, __bss
	ld	de, __common
	ld	bc, __common_size
	ldir
	ld	de, __commondata
	ld	bc, __commondata_size
	ldir

	; then the discard
	; Discard can just be linked in but is next to the buffers
	ld	de, __discard
	ld	bc, __discard_size-1
	add	hl, bc
	ex	de, hl
	add	hl, bc
	ex	de, hl
	lddr
	ldd

	; then zero the data area
	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir

	; Zero buffers area
	ld	hl, __buffers
	ld	de, __buffers + 1
	ld	bc, __buffers_size - 1
	ld	(hl), 0
	ldir

	; The ADL stack is in MOS memory which is now a user bank
	.byte	0x5B,0x31		; ld.lil sp,{KERNEL_BANK,adl_stack}
	.word	adl_stack
	.byte	KERNEL_BANK

	call	init_hardware
	call	_fuzix_main
	; Should never return
	di
stop:	halt
	jr	stop

	.bss

	.ds	32
adl_stack:
