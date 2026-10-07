; dzip reading
;
; SPDX-FileCopyrightText: Copyright 2026 Ciaran Anscomb
; SPDX-License-Identifier: GPL-2.0-or-later

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; DATA
;
; Read and decompress dzipped 16K of data.

	.common

	.export read_16k

read_16k:
	sta @0xFF35	; work area = dst page

	lda #0x2E
	bsr con_chrout	; print a '.'
	bsr con_anim_crs

	ldu #0x4000	; chunk destination (mapped)
dunzip:
duz_loop:
	bsr con_crs_tick
duzl5:	bsr read_word
	tsta
	bpl duz_run	; run of 1-128 bytes
	tstb
	bpl duz_7_7
duz_14_8:
	lslb	; drop top bit of byte 2
	asra
	rorb	; asrd
	leay d,u
	bsr read_byte
	bra dcl10	; copy 1-256 bytes (0 == 256)
duz_7_7:
	leay a,u	; copy 1-128 bytes
dcl10:	lda ,y+
	sta ,u+
	incb
	bvc dcl10	; count UP until B == 128
	bra dcl80
dcl1:	bsr read_byte
duz_run:
	stb ,u+
	inca
	bvc dcl1	; count UP until B == 128
dcl80:	cmpu #0x8000
	blo duz_loop
	rts
