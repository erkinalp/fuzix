;
;	SD card on the eZ80 SPI, CS on PB4. MOS has set up the pins. In
;	common as raw I/O runs with the user bank mapped.
;
	.z180

#include "kernelu.def"

	.common

	.export	_sd_spi_slow
	.export	_sd_spi_fast
	.export	_sd_spi_raise_cs
	.export	_sd_spi_lower_cs
	.export	_sd_spi_rx_byte
	.export	_sd_spi_tx_byte
	.export	_sd_spi_rx_sector
	.export	_sd_spi_tx_sector

_sd_spi_slow:
	ld	a, 23			; 18.432MHz / (2 * 23) = 400KHz
	jr	sd_spi_clock
_sd_spi_fast:
	ld	a, 3			; 3.072MHz (the fastest master rate)
sd_spi_clock:
	ld	l, a
	xor	a
	out0	(SPI_CTL), a		; must be disabled to change the rate
	out0	(SPI_BRG_H), a
	ld	a, l
	out0	(SPI_BRG_L), a
	ld	a, 0x30			; enabled, master, mode 0
	out0	(SPI_CTL), a
	ret

_sd_spi_raise_cs:
	in0	a, (PB_DR)
	or	0x10
	out0	(PB_DR), a
	ret

_sd_spi_lower_cs:
	in0	a, (PB_DR)
	and	0xEF
	out0	(PB_DR), a
	ret

;
;	Byte to send is in L
;
_sd_spi_tx_byte:
	pop	de
	pop	hl
	push	hl
	push	de
	ld	a, l
	out0	(SPI_TSR), a
tx_wait:
	in0	a, (SPI_SR)		; reading clears the done flag
	rla
	jr	nc, tx_wait
	ret				; no need to read the dummy byte

_sd_spi_rx_byte:
	ld	a, 0xFF
	out0	(SPI_TSR), a
rx_wait:
	in0	a, (SPI_SR)
	rla
	jr	nc, rx_wait
	in0	a, (SPI_RBR)
	ld	l, a
	ld	h, 0
	ret

;
;	Map the right bank for the transfer
;
sd_map:
	ld	a, (_td_raw)
#ifdef CONFIG_SWAP
	cp	2
	jr	nz, sd_map_user
	ld	a, (_td_page)
	jp	map_for_swap
sd_map_user:
#endif
	or	a
	ret	z			; kernel buffer
	jp	map_proc_always		; user memory

_sd_spi_rx_sector:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	sd_map
	ld	d, 2
	ld	b, 0			; 2 x 256 bytes
rx_loop:
	ld	a, 0xFF
	out0	(SPI_TSR), a
rx_sec_wait:
	in0	a, (SPI_SR)
	rla
	jr	nc, rx_sec_wait
	in0	a, (SPI_RBR)
	ld	(hl), a
	inc	hl
	djnz	rx_loop
	dec	d
	jr	nz, rx_loop
	pop	bc
	jp	map_kernel

_sd_spi_tx_sector:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	sd_map
	ld	d, 2
	ld	b, 0			; 2 x 256 bytes
tx_loop:
	ld	a, (hl)
	inc	hl
	out0	(SPI_TSR), a
tx_sec_wait:
	in0	a, (SPI_SR)
	rla
	jr	nc, tx_sec_wait
	djnz	tx_loop
	dec	d
	jr	nz, tx_loop
	pop	bc
	jp	map_kernel
