; Raw data reading
;
; SPDX-FileCopyrightText: Copyright 2026 Ciaran Anscomb
; SPDX-License-Identifier: GPL-2.0-or-later

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; DATA
;
; Read 16K of data.

	.common

	.export read_16k

read_16k:
	sta @0xFF35	; work area = dst page

	lda #0x2E
	bsr con_chrout	; print a '.'
	bsr con_anim_crs

	ldu #0x4000	; chunk destination (mapped)
r16l0:	bsr read_word
	std ,u++
	bsr con_crs_tick
	cmpu #0x8000
	blo r16l0
	rts
