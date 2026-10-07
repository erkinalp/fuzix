	.export _devide_read_data
	.export _devide_write_data

;
;	If we ever do a native driver for M3SE we'll want to do something
;	different here for that and use ide_select to switch interface types
;

IDE_REG_DATA			.equ	0x40

	.common

map:
	ld	hl,8
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	a,(_td_raw)
	ld	bc,IDE_REG_DATA
	; Swap not yet supported
	or	a
	ret	z	; Kernel - no remap
	dec	a
	jp	z, map_proc_always
	ld	a,(_td_page)
	jp	map_proc_a

_devide_read_data:
	push	bc
	call	map
	inir
	inir
unmap:
	pop	bc
	ld	a,(_td_raw)
	or	a
	ret	z
	jp	map_kernel_restore

_devide_write_data:
	push	bc
	call	map
	otir
	otir
	jr	unmap
