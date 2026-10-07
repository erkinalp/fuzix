        ; exported symbols
	.export _suspend

#include "kernelu.def"

	; Starts at 0x1000 at the moment

	; Entered with bank = 1 from the bootstrap logic
	; A holds the machine type: 0 = SBC64/MBC64 1 = ZRCC

resume_sp .equ 0x0080
resume_tag .equ 0x0084

	.code

	jp start
	jp resume
	.word 0x10AD

start:
	ld sp, kstack_top

	; move the common memory where it belongs    
	ld hl, __bss
	ld de, __common
	ld bc, __common_size
	ldir
	ld de, __commondata
	ld bc, __commondata_size
	ldir
	; then the discard
	; Discard can just be linked in but is next to the buffers
	ex de,hl
	ld hl, __discard
	ld bc, __discard_size-1
	add hl,bc
	ex de,hl
	add hl,bc
	; May be overlapping its own destination
	lddr
	ldd

	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl),0
	ldir

	; Zero buffers area
	ld hl, __buffers
	ld de, __buffers + 1
	ld bc, __buffers_size - 1
	ld (hl), 0
	ldir

	ld (_mach_zrcc),a

	call init_hardware
	call _fuzix_main
	; Should never return
	di
stop:	halt
	jr stop
;
;	Helpers for the battery backed memory model
;
resume:
	di
	ld sp, (resume_sp)
	pop iy
	pop ix
	ld hl, 0
	ld (resume_tag), hl
	ret

_suspend:
	push ix
	push iy
	ld (resume_sp), sp
	ld hl,0xC0DE
	ld (resume_tag), hl
	ld hl, suspended
	call outstring
	di
	halt
suspended:
	.ascii 'Suspended, you may now power off'
	.byte 13,10,0


	