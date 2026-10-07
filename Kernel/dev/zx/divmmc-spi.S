
	.export _sd_spi_rx_sector
	.export _sd_spi_tx_sector

	.common

setup:
#ifdef BANKED_Z80
	ld	hl,6
#else
	ld	hl,6
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	bc, 0xEB
	ld	a, 0x05
	out	(0xfe),a
	ld	a,(_td_raw)
	or	a
	ret	z
	dec	a
	jp	z, map_proc_always
	ld	a,(_td_page)
	jp	map_for_swap
	

_sd_spi_rx_sector:
	push	bc
	call	setup
	inir
	ld	a, 0x02
	out	(0xfe), a
	inir
out:
	ld	a, (_vtborder)
	out	(0xfe), a
	pop	bc
	ld	a, (_td_raw)
	or	a
	ret	z
	jp	map_kernel
	ret

_sd_spi_tx_sector:
	push	bc
	call	setup
	otir
	ld	a, 0x02
	out	(0xfe), a
	otir
	jr	out	