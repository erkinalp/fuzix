	; Methods provided
	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_across
	.export _clear_lines
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

	.export video_init
	.export _fontbase

#include "../../build/kernel.def"
#include "../../cpu-6809/kernel09.def"

	.common

;
;	Compute the video base address
;	A = X, B = Y, returns an address in X
;
;	This is a simple bitmap, so chracters are just copied 8x8
;
;	x 320 wants optimizing
;
;	Video is at 4000-5FFF
;
vidaddr:
	sta	,-s
	lslb
	stb	,-s
	lslb
	lslb
	addb	,s+
	; b is now 10 x Y and fits in a byte (240 is max)
	; now shuffle it into D so it ends up another x 32
	clra
	lslb
	rola
	lslb
	rola
	lslb
	rola
	lslb
	rola
	lslb
	rola
	addb	,s+		; add in the X value
	adda	#0x40		; Screen base 0x4000
	tfr	d,y
	jmp	map_video
;
;	plot_char(int8_t y, int8_t x, uint16_t c)
;
_plot_char:
	pshs cc
	orcc #$50
	sts vsp_save
	ldx 4,s
	lda _vtattr		; this won't be mapped when we are in video space
	sta vtattrcp
	lda 3,s
	lds #videostack
	bsr vidaddr		; preserves X (holding the char)
	tfr x,d
	andb #$7F		; no high font bits
	clra
	rolb			; multiply by 8
	rola
	rolb
	rola
	rolb
	rola
	addd _fontbase
	tfr d,x
	ldb vtattrcp
	andb #0x3F		; drop the bits that don't affect our video
	beq plot_fast

	;
	;	General purpose plot with attributes, we only fastpath
	;	the simple case
	;
	clra
plot_loop:
	sta _vtrow
	ldb vtattrcp
	cmpa #7		; Underline only applies on the bottom row
	beq ul_this
	andb #0xFD
ul_this:
	cmpa #3		; italic shift right for < 3
	blt ital_1
	andb #0xFB
	bra maskdone
ital_1:
	cmpa #5		; italic shift right for >= 5
	blt maskdone
	bitb #0x04
	bne maskdone
	orb #0x40		; spare bit borrow for bottom of italic
	andb #0xFB
maskdone:
	lda ,-x			; now throw the row away for a bit
	bitb #0x10
	bne notbold
	lsra
	ora 1,x			; shift and or to make it bold
notbold:
	bitb #0x04		; italic by shifting top and bottom
	beq notital1
	lsra
notital1:
	bitb #0x40
	beq notital2
	lsla
notital2:
	bitb #0x02
	beq notuline
	lda #0xff		; underline by setting bottom row
notuline:
	bitb #0x01		; inverse or not
	beq plot_ninv		; 
	coma			; inverted
plot_ninv:
	bitb #0x20		; overstrike or plot ?
	bne overstrike
	sta ,y
	bra plotnext
overstrike:
	anda ,y
	sta ,y
plotnext:
	leay 40,y
	lda _vtrow
	inca
	cmpa #8
	bne plot_loop
	bra unmapc
;
;	Fast path for normal attributes
;	Yes.. the ROM font really is stored upside down!
;
plot_fast:
	lda ,-x			; simple 8x8 renderer for now
	sta 0,y
	lda ,-x
	sta 40,y
	lda ,-x
	sta 80,y
	lda ,-x
	sta 120,y
	lda ,-x
	sta 160,y
	lda ,-x
	sta 200,y
	lda ,-x
	sta 240,y
	lda ,-x
	sta 280,y
unmapc:
	jsr unmap_video
	lds vsp_save
	puls cc,pc

;
;	void scroll_up(void)
;
_scroll_up:
	pshs cc
	orcc #$50
	sts vsp_save
	lds #videostack
	jsr map_video
	ldy #VIDEO_BASE
	leax 320,y
vscrolln:
	; Unrolled line by line copy
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	ldd ,x++
	std ,y++
	cmpx video_endptr
	lbne vscrolln
	jmp unmap

;
;	void scroll_down(void)
;
_scroll_down:
	pshs cc
	orcc #$50
	sts vsp_save
	lds #videostack
	jsr map_video
	ldy #VIDEO_END
	leax -320,y
vscrolld:
	; Unrolled line by line loop
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	ldd ,--x
	std ,--y
	cmpx video_startptr
	lbne vscrolld
unmap:
	jsr unmap_video
	lds vsp_save
	puls cc,pc

video_startptr:
	.word	VIDEO_BASE
video_endptr:
	.word	VIDEO_END

;
;	clear_across(int8_t y, int8_t x, uint16_t l)
;
_clear_across:
	pshs cc
	orcc #$50
	sts  vsp_save
	lda 3,s		; x into A, B already has y
	ldx 4,s
	lds  #videostack
	jsr vidaddr	; Y now holds the address
	tfr x,d		; Shuffle so we are writng to X and the counter
	tfr y,x		; l is in d
	clra
	incb
	bra cleara
clearnext:
	sta ,x
	sta 40,x
	sta 80,x
	sta 120,x
	sta 160,x
	sta 200,x
	sta 240,x
	sta 280,x
	leax 1,x
cleara:
	decb
	bne clearnext
	bra unmap
;
;	clear_lines(int8_t y, int8_t ct)
;
_clear_lines:
	pshs cc
	orcc #$50
	sts  vsp_save
	lda  3,s
	lsla
	lsla
	lsla
	sta  vid_work
	lds  #videostack
	clra			; b holds Y pos already
	jsr vidaddr		; y now holds ptr to line start
	tfr y,x
	pshs a
	clra
	clrb
	beq nolines
wipel:
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	dec vid_work		; count of lines
	bne wipel
nolines:
	jmp unmap

_cursor_on:
	pshs cc
	orcc #$50
	sts  vsp_save
	lda  3,s
	lds #videostack
	jsr vidaddr
	tfr y,x
	stx cursor_save
do_cursor:
	com ,x
	com 40,x
	com 80,x
	com 120,x
	com 160,x
	com 200,x
	com 240,x
	com 280,x
	jmp unmap

_cursor_off:
	pshs cc
	orcc #$50
	sts  vsp_save
	lds  #videostack
	ldb _vtattr
	bitb #0x80
	bne nocursor
	ldx cursor_save
	cmpx #$FFFF
	beq nocursor
	jsr map_video
	bra do_cursor
nocursor:
	lds vsp_save
	puls y,cc,pc
_vtattr_notify:
_cursor_disable:
	rts

;
;	We are always on the kernel stack for this so no switch is
;	needed, likewise ints are off.
;
video_init:
	jsr	map_video
	ldx	#VIDEO_BASE
	ldd	#0
vidwipe:
	std	,x++
	cmpx	#VIDEO_END
	bne 	vidwipe
	jmp	unmap_video

;
;	The TO9 memory map is tricky as we have to keep the video over
;	some of our common space. Instead put the video data in high as
;	the kernel will be mapped whenever we are doing video work
;
	.commondata
cursor_save:
	.word	$FFFF
_vtrow:
	.byte	0
vtattrcp:
	.byte	0
_fontbase:
	.word	0
vid_work:
	.byte	0
vsp_save:
	.word	0		; saved stack switch
	.ds	64
videostack:
