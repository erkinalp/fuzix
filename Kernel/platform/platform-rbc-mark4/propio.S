
	.export _plt_prop_sd_read
	.export _plt_prop_sd_write


#include "kernelu.def"

	.common

prop_setup:
	ld bc, 0xAB				; port and count
	ld a, (_td_raw)
	or a
	jp z, map_buffers
	dec a
	jp z, map_proc_always
	ld a,(_td_page)
	jp map_for_swap

_plt_prop_sd_read:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	prop_setup
	inir                                    ; transfer first 256 bytes
	inir                                    ; transfer second 256 bytes
	pop	bc
	jp	map_kernel

_plt_prop_sd_write:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	prop_setup
	otir                                    ; transfer first 256 bytes
	otir                                    ; transfer second 256 bytes
	pop	bc
	jp	map_kernel
