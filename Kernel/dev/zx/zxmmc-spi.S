#include "../../build/kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.common
;
; Could also unroll these a bit for speed
;

	.export _sd_spi_rx_sector
	.export _sd_spi_tx_sector

setup:
#ifdef BANKED_Z80
	ld	hl,8
#else
	ld	hl,6
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	bc,0x3F
	ld	a,(_td_raw)
	or	a
	ret	z
	dec	a
	jp	z, map_kernel
	ld	a,(_td_page)
	jp	map_for_swap

_sd_spi_rx_sector:
	push	bc
	call	setup
	inir
	ld	a,2
	out	(0xFE),a
	inir
	; Required accordign to CP/M driver
	in	a,(0x3F)
	nop
	nop
	in	a,(0x3F);
out:
	ld	a,(_vtborder)
	out	(0xFE),a
	pop	bc
	ld	a,(_td_raw)
	or	a
	ret	z
	jp	map_kernel

_sd_spi_tx_sector:
	push	bc
	call	setup
	push	af
	otir
	ld	a,2
	out	(0xFE),a
	otir
	jr	out
