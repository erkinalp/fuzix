;
;	This is run 50 time a second so we do it in asm and also return
;	0 if nothing changed. That allows us to avoid the main tty
;	processing on most interrupt events which saves us a lot of
;	clocks.
;
;	FIXME: optimise out use of e in favour of rrc b c flag clear
;

	.code
	.export _update_keyboard

_update_keyboard:
	ld	hl, _keybuf
	ld	c, 0xFE
	ld	b, 0x7f
	ld	de, 8	; 8 keyboard ports, 7FFE, BFFE, DFFE and so on
			; D to 0 for no change found
read_halfrow:
	in	a, (c)
	cpl
	cp	(hl)
	jr	z,nochange
	inc	d	; there 8 ports so we cannot overflow
	ld	(hl), a
nochange:
	rrc	b
	inc	hl
	dec	e
	jr	nz, read_halfrow
	ld	l,d
	ret
