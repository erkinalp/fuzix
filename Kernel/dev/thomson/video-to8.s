# 1 "../../dev/thomson/video-to8.S"
	; Methods provided
	export _plot_char
	export _scroll_up
	export _scroll_down
	export _clear_across
	export _clear_lines
	export _cursor_on
	export _cursor_off
	export _cursor_disable
	export _vtattr_notify

	export video_init
	export _fontbase
# 1 "../../dev/thomson/../../build/kernel.def"
U_DATA__TOTALSIZE           equ 0x0200        ; 256+256

VIDEO_BASE		    equ 0x0000	     ; 8K mapped in the video window
VIDEO_END		    equ 0x2000	     ; for now
VIDEO_OFF		    equ 0x00	     ; mapped at 0x00

PROGBASE                    equ 0x6400       ; programs and data start here

IOPAGE			    equ 0xE7	     ; I/O window
# 1 "../../dev/thomson/../../cpu-6809/kernel09.def"
; Keep these in sync with struct u_data!!
U_DATA__U_PTAB              equ 0   ; struct p_tab*
U_DATA__U_PAGE              equ 2   ; uint16_t
U_DATA__U_PAGE2             equ 4   ; uint16_t
U_DATA__U_INSYS             equ 6   ; bool
U_DATA__U_CALLNO            equ 7   ; uint8_t
U_DATA__U_SYSCALL_SP        equ 8   ; void *
U_DATA__U_RETVAL            equ 10  ; int16_t
U_DATA__U_ERROR             equ 12  ; int16_t
U_DATA__U_SP                equ 14  ; void *
U_DATA__U_ININTERRUPT       equ 16  ; bool
U_DATA__U_CURSIG            equ 17  ; int8_t
U_DATA__U_ARGN              equ 18  ; uint16_t
U_DATA__U_ARGN1             equ 20  ; uint16_t
U_DATA__U_ARGN2             equ 22  ; uint16_t
U_DATA__U_ARGN3             equ 24  ; uint16_t
U_DATA__U_ISP               equ 26  ; void * (initial stack pointer when _exec()ing)
U_DATA__U_TOP               equ 28  ; uint16_t
U_DATA__U_BREAK             equ 30  ; uint16_t
U_DATA__U_CODEBASE          equ 32  ; uint16_t
U_DATA__U_SIGVEC            equ 34  ; table of function pointers (void *)

; Keep these in sync with struct p_tab!!
P_TAB__P_STATUS_OFFSET      equ 0
P_TAB__P_FLAGS_OFFSET	    equ 1
P_TAB__P_TTY_OFFSET         equ 2
P_TAB__P_PID_OFFSET         equ 3
P_TAB__P_PAGE_OFFSET        equ 15

P_RUNNING                   equ 1            ; value from include/kernel.h
P_READY                     equ 2            ; value from include/kernel.h

PFL_BATCH		    equ 4            ; value from include/kernel.h

OS_BANK                     equ 0            ; value from include/kernel.h

EAGAIN                      equ 11           ; value from include/kernel.h


; Keep in sync with struct blkbuf
BUFSIZE 		    equ 520
# 18 "../../dev/thomson/video-to8.S"
	.common

;
;	Compute the video base address
;	A = X, B = Y, returns an address in X
;
;	Two interleaved banks. So we actually do the 40 column maths
;	then fix up based on X
;
;	This is a simple bitmap, so chracters are just copied 8x8
;
;	x 320 wants optimizing
;
;	Video is at 0000-3FFF, with character bytes alternating
;	between the two 8K chunks
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
	lsr	,s
	bcc	low_bank
	adda	#$20		; ever alt char is in other bank
low_bank:
	addb	,s+		; add in the X value
	tfr	d,y
	adda	#VIDEO_OFF
	jmp	map_video
;
;	plot_char(int8_t y, int8_t x, uint16_t c)
;
_plot_char:
	lda _vtattr		; this won't be mapped when we are in video space
	sta vtattrcp
	lda 2,s
	ldx 3,s
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
	bra unmap_videoc
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
unmap_videoc:
	jmp map_kernel
	
;
;	void scroll_up(void)
;
_scroll_up:
	jsr map_video
	ldy #VIDEO_BASE
	leax 320,y
vscrolln:
	; Unrolled line by line copy. Do the offsets as we go to avoid
	; tearing
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	ldd $2000,x
	std $2000,y
	ldd ,x++
	std ,y++
	cmpx video_endptr
	lbne vscrolln
	jmp unmap_video

;
;	void scroll_down(void)
;
_scroll_down:
	jsr map_video
	ldy #VIDEO_END
	leax -320,y
vscrolld:
	; Unrolled line by line loop
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	ldd ,--x
	std ,--y
	ldd $2000,x
	std $2000,y
	cmpx video_startptr
	lbne vscrolld
unmap_video:
	jsr map_kernel
	puls pc

video_startptr:
	.word	VIDEO_BASE
video_endptr:
	.word	VIDEO_END

;
;	clear_across(int8_t y, int8_t x, uint16_t l)
;
_clear_across:
	lda 2,s		; x into A, B already has y
	jsr vidaddr	; Y now holds the address
	ldd 3,s		; Shuffle so we are writng to X and the counter
	tfr y,x		; l is in d
	clra
clearnext:
	; Optimise using two regs ?
	sta ,x
	sta 40,x
	sta 80,x
	sta 120,x
	sta 160,x
	sta 200,x
	sta 240,x
	sta 280,x
	leax $2000,x
	sta ,x
	sta 40,x
	sta 80,x
	sta 120,x
	sta 160,x
	sta 200,x
	sta 240,x
	sta 280,x
	leax $1FFF,x	;	back and on one char
	decb
	bne clearnext
	bra unmap_video
;
;	clear_lines(int8_t y, int8_t ct)
;
_clear_lines:
	clra			; b holds Y pos already
	jsr vidaddr		; y now holds ptr to line start
	tfr y,x
	clra
	clrb
	lsl 2,s
	lsl 2,s
	lsl 2,s
	; Optimise this using two regs ?
wipel:
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	std $2000,x
	std ,x++
	dec 2,s			; count of lines
	bne wipel
	jmp unmap_video

_cursor_on:
	lda  2,s
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
	jmp unmap_video

_cursor_off:
	ldb _vtattr
	bitb #0x80
	bne nocursor
	ldx cursor_save
	cmpx #$FFFF
	beq nocursor
	pshs y
	jsr map_video
	bra do_cursor
nocursor:
_vtattr_notify:
_cursor_disable:
	rts

video_init:
	jsr	map_video
	ldx	#VIDEO_BASE
	ldd	#0
vidwipe:
	std	,x++
	cmpx	#VIDEO_END
	bne 	vidwipe
	jmp	map_kernel

	.commondata

cursor_save:
	.word	$FFFF
_vtrow:
	.byte	0
vtattrcp:
	.byte	0
_fontbase:
	.word	0
