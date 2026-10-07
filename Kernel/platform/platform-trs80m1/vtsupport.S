;
;	Do this in assembler so we can keep the vtbackbuf banked
;
;	Must be in the same bank as vt
;

	.export _vtswap
	.export vtbufinit
	.export _vtbase
	.export _video_lower

	.export _cursor_off
	.export _cursor_disable
	.export _cursor_on
	.export _plot_char
	.export _clear_lines
	.export _clear_across
	.export _vtattr_notify
	.export _scroll_up
	.export _scroll_down

	.overlay2
_vtbackbuf:
	.ds 1024

	.commondata
_vtbase:
	.word	0x3C00
	.word	_vtbackbuf
_video_lower:
	.byte	1	; Assume we have lower case

	.overlay2

_vtswap:
	push	bc
	ld	hl, 0x3C00
	ld	de, _vtbackbuf
	ld	bc, 1024	; 64 * 16
exchit:
        push bc
        ld	a, (de)	; Could be optimised but its only 1K
        ld	c, (hl)	; Probably worth doing eventuallly
        ex	de, hl
        ld	(hl), c
        ld	(de), a
        inc	hl
        inc	de
        pop	bc
        dec	bc
        ld	a, b
        or	c
        jr	nz, exchit
	pop	bc
        ret
vtbufinit:
	push	bc
	ld	hl,0x3C00
	xor	a
	ld	(hl),a
	cp	(hl)
	jr	z, have_lower
	xor	a
	ld	(_video_lower),a
have_lower:
	ld	(hl),32
	ld	hl,_vtbackbuf
	ld	de,_vtbackbuf+1
	ld	bc,1023
	ld	(hl),' '
	ldir
	pop	bc
	ret

;
;	This is basically VT_SIMPLE but done in asm so we know all our
;	I/O happens with the right things banked
;

vtbase:
	ld	hl,(_vtbase)
	ld	a,(_curtty)
	or	a
	ret	z
	ld	hl,(_vtbase + 2)
	ret

;
;	Must preserve BC
;	Turn D,E into a display address
;
addr:	call	vtbase
	ld	a,d		; save X
	ld	d,e
	ld	e,0
	srl	d		;  DE = Y * 64
	rr	e
	srl	d
	rr	e
	add	a,e	; add in X
	ld	e,a
	add	hl,de	; add in base
	ret

_cursor_off:
	ld	hl,(cpos)
	ld	a,h
	or	a	;	00xx isn't valid so no need to check l
	ret	z
	ld	a,(csave)
	ld	(hl),a
	xor	a
	ld	(cpos+1),a
_cursor_disable:
	ret

_cursor_on:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	call	addr
	ld	a,(hl)
	ld	(hl),'_'
	ld	(csave),a
	ld	(cpos),hl
	ret

; FIXME: should not corrupt ix
_plot_char:
	push	ix
	ld	ix,6
	add	ix,sp
	ld	e,(ix + 0)
	ld	d,(ix + 2)

	call	addr
	ld	a,(_video_lower)	; hot path, maybe we should runtime
	or	a			; patch
	ld	a, (ix + 4)
	jr	nz, plot_lower
	;
	; Deal with gate Z30 fun and games. The default model 1
	; doesn't have bit 6 of the video RAM instead it's generated
	; by looking at bit 5 and bit 7, and setting bit 6 if both
	; are low. If we try to print in the lower case range then
	; bit 5 is high, and we end up printing symbols 32-63
	; instead.
	;
	and	0xE0		; Z30 bits
	cp	0x60		; problem case
	ld	a, (ix + 4)
	jr	nz, plot_lower
	res	5,a		; force into upper
plot_lower:
	ld	(hl),a
	pop	ix
	ret

_clear_lines:
	push	bc
	ld	hl,6
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)
	xor	a
	cp	c
	jr	z,clear_done
	ld	d,0
	call	addr
	ld	a,32
clear0:
	ld	b,64		; line width
clear1:
	ld	(hl),a
	inc	hl
	djnz	clear1
	dec	c
	jr	nz, clear0
clear_done:
	pop	bc
	ret

_clear_across:
	push	ix
	ld	ix,6
	add	ix,sp
	ld	e,(ix + 0)
	ld	d,(ix + 2)
	call	addr
	push	bc
	ld	b,(ix + 4)
clear2: ld	(hl),a
	inc	hl
	djnz	clear2
	pop	bc
	pop	ix
_vtattr_notify:
	ret

_scroll_up:
	push	bc
	call	vtbase		; HL now the base of the video
	push	hl
	ld	de,64
	add	hl,de		; HL is now the video second line
	pop	de			; top of video (destination)
	ld	bc,1024-64
	ldir
	pop	bc
	ret

_scroll_down:
	push	bc
	call	vtbase
	ld	de,1024-64		
	add	hl,de		; points to start of last line
	dec	hl			; end of line before last
	push	hl
	ld	de,64
	add	hl,de		; last char
	pop	de
	ex	de,hl
	ld	bc,1024-64
	lddr
	pop	bc
	ret

csave:	.byte	0
cpos:	.word	0
