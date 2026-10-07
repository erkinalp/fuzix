# 1 "zxvideo.S"
;
;        Timex VT primitives but at 0xC0 instead
;
;	512 pixel mode
;
        ; exported symbols
        .export _plot_char
        .export _scroll_down
        .export _scroll_up
        .export _cursor_on
        .export _cursor_off
	.export _cursor_disable
        .export _clear_lines
        .export _clear_across
        .export _do_beep
	.export _curattr

	; Build the video library as the only driver
	; We will make this includable at some point



	.common

;
;       zx128 vt primitives hacked a bit
;
;	Will be replaced by Timex video shortly
;
        ; exported symbols
        .export tmx_plot_char
        .export tmx_scroll_down
        .export tmx_scroll_up
        .export tmx_cursor_on
        .export tmx_cursor_off
	.export tmx_cursor_disable
        .export tmx_clear_lines
        .export tmx_clear_across
        .export tmx_do_beep
	.export _curattr

videopos:
	srl	d	    ; we alternate pixels between two screens
	push	af
        ld	a, e
        and 	7
        rrca
        rrca
        rrca 
        add	a, d
        ld	d, e
        ld	e, a
	pop	af
	jr	c, rightside
        ld	a, d
        and	0x18
        or	0xC0	    ; Left screen
        ld	d, a
	jp	map_video_save
rightside:
        ld	a, d
        and	0x18
        or	0xE0	    ; Left screen
        ld	d, a
	jp	map_video_save


_plot_char:

tmx_plot_char:
	push	bc
	ld	hl, 4
	add	hl, sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)		; D = X, E = Y C = char

	ld	hl, (_vtattr)	; l is vt attributes

        call	videopos	; preserves l

        ld	b,  0            ; calculating offset in font table
        ld	a, c

	bit	6, l		; ALTCHAR ?
	jr	z, normch
	or	0x80		; clears carry
	jr	doch
normch:
	and	127		; clears carry
doch:
        rla
        rl	b
        rla
        rl	b
        rla
        rl	b
        ld	c, a

	ld	a,l		; save vtattr bits

        ld	hl,  _fontdata_8x8    ; font
        add	hl, bc          ; hl points to first byte of char data

	ld	c,a		; vtattr bits into C
	; We do underline for now - not clear italic or bold are useful
	; with the font we have.

        ; printing
plot_char_loop:
        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl              ; next byte of char data
        inc	d               ; next screen line

        ld	a, (hl)
	bit	1, c	    ; underline ?
	jr	nz, last_ul
plot_attr:
        ld	(de), a
	pop	bc
	jp	map_kernel

last_ul:
	ld	a, 0xff
	jr	plot_attr


_clear_lines:

tmx_clear_lines:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	; This way we handle 0 correctly
	inc	d
	jr	nextline

clear_next_line:
        push	de
        ld	d, 0            ; from the column  0
        ld	c, 64           ; clear 64 cols

        call	do_clear_across

        pop	de
        inc	e
nextline:
        dec	d
        jr	nz, clear_next_line
	pop	bc
 	jp	map_kernel



_clear_across:

tmx_clear_across:
	push	bc
	ld	hl, 4
	add	hl, sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)
	; DE = coords 
	; C = count
	ld	a, c
	or	a
	call	nz, do_clear_across
	pop	bc
	jp	map_kernel

	.export do_clear_across

do_clear_across:
        call	videopos       ; first pixel line of first character in DE

	; Save it in HL
	ld	h, d
	ld	l, e

        xor	a

	;  Figure out if starting L or R
	bit	5, d
	jr	nz, clear_start_r

        ; no boundary checks. Assuming that D + C < SCREEN_WIDTH
clear_line:
	; Do the left character
        ld b,  8            ; 8 pixel lines to clear for this char
clear_char_l:
        ld	(de), a
        inc	d
        djnz	clear_char_l

	; Left was final char
	dec	c
	ret	z

	; Recover position from HL and move 8K up
	ld	d, h
	ld	e, l
	set	5, d

clear_start_r:
        ld	b, 8            ; 8 pixel lines to clear for this char
clear_char_r:
        ld	(de), a
        inc	d
        djnz	clear_char_r

        inc	hl
	ld	d, h
	ld	e, l

	; Next character ?
        dec	c
        jr	nz, clear_line
	ret

copy_line:
        ; HL - source, DE - destination
        ; convert line coordinates to screen coordinates both for DE and HL
        push	de
        ex	de, hl
        call	videopos
        ex	de, hl
        pop	de
        call	videopos

        ld	c, 8

copy_line_nextchar:
        push	hl
        push	de

        ld	b, 32

copy_pixel_line:
        ld	a, (hl)
        ld	(de), a
        inc	e
        inc	l
        djnz	copy_pixel_line

        pop	de
        pop	hl
	push	hl
	push	de

	set	5, d		; Even half
	set	5, h
	ld	b, 32
copy_pixel_line_r:
	ld	a, (hl)
	ld	(de), a
	inc	e
	inc	l
	djnz	copy_pixel_line_r

	pop	de
	pop	hl

        inc	d
        inc	h
        dec	c
        jr	nz, copy_line_nextchar
        ret

        ; TODO: the LDIR way should be much faster


_scroll_down:

tmx_scroll_down:
        ; set HL = (0, 22), DE = (0, 23)
	push	bc
        xor	a
        ld	d, a
        ld	h, a
        ld	l,  22
        ld	e,  23
        ld	c,  23           ; 23 lines to move

	call	map_video_save

loop_scroll_down:
        push	hl
        push	de
        push	bc

        call	copy_line

        pop	bc
        pop	de
        pop	hl

        dec	l
        dec	e
        dec	c
        jr	nz, loop_scroll_down

	pop	bc
        jp	map_kernel



_scroll_up:

tmx_scroll_up:
        ; set HL = (0, 1), DE = (0, 0)
	push	bc
        xor	a
        ld	d, a
        ld	e, a
        ld	h, a
        ld	l, 1
        ld	c, 23           ; 23 lines to move

	call	map_video_save

loop_scroll_up:
        push	hl
        push	de
        push	bc

        call copy_line

        pop	bc
        pop	de
        pop	hl

        inc	l
        inc	e
        dec	c
        jr	nz, loop_scroll_up
	pop	bc
	jp	map_kernel


_cursor_on:

tmx_cursor_on:
	push	bc
	ld	hl, 4
	add	hl, sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
        ld	(cursorpos), de

        call	videopos
        ld	a,  7
        add	a, d
        ld	d, a
	ld	a,(de)
        cpl
        ld	(de), a
	pop	bc
        jp	map_kernel


_cursor_disable:
_cursor_off:

tmx_cursor_disable:
tmx_cursor_off:
        ld	de, (cursorpos)
        call	videopos
        ld	a,  7
        add	a, d
        ld	d, a
	ld	a,(de)
	cpl
        ld	(de), a
	jp	map_kernel


_do_beep:

tmx_do_beep:
        ret

	.data

cursorpos:
        .word	0

	.commondata
_curattr:
	.byte	7
