	; Methods provided
	.export _map_video
	.export _unmap_video
	.export _vid256x192
	.export _m6847_plot_char
	.export _m6847_scroll_up
	.export _m6847_scroll_down
	.export _m6847_clear_across
	.export _m6847_clear_lines
	.export _m6847_cursor_on
	.export _m6847_cursor_off
	.export _m6847_cursor_disable
	.export _m6847_vtattr_notify

	.export _m6847_video_read
	.export _m6847_video_write
	.export _m6847_video_cmd

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.code

; These are not used yet.
; When we unmap the common page to work on the video below, whatever
; has been written there (kstack in particular) can still be read
; but if anything is written it will be lost once we remap the common.
_map_video:
	tfr cc,a
	sta cc_video
	orcc #0x10		; disable interrupt while video is mapped
	lda #VBANKV		; since bits of the kernel disappear
	sta 0xff34+KBANKV
	rts

_unmap_video:
	lda #KBANKV
	sta 0xff34+KBANKV
	lda cc_video
	tfr a,cc
	rts

;
; Dragon video drivers
;
; SAM V2=1 V1=1 V0=-
; 6847 A/G=1 GM2=1 GM1=1 GM0=1
;
_vid256x192:
	; V=6 (RG4)
	sta 0xffc0
	sta 0xffc3
	sta 0xffc5
	; SAMx8 base
	ldd #VIDEO_FREG
	std 0xff38
	; VDG GFX, GM=7 (RG6), CSS=0
	lda 0xff22
	anda #0x07
	ora #0xf0
	sta 0xff22
	rts

;
; Compute the video base address
; A = X, B = Y
;
vidaddr:
	ldy #VIDEO_BASE
	leay d,y		; 256 x Y + X
	rts
;
; plot_char(int8_t y, int8_t x, uint16_t c)
;
_m6847_plot_char:
	tfr b,a
	ldb 2,s			; A := y, B := x
	bsr vidaddr
	ldd 3,s			; D := c
plot_patch:
	andb #0x7f		; mask char - patched on vtattr change
	lslb			; multiply by 8
	rola
	lslb
	rola
	lslb
	rola
	addd #_fontdata_8x8	; relative to font
	tfr d,x
	jsr _map_video
	ldb _vtattr
	andb #0x3f		; drop the bits that don't affect our video
	beq plot_fast

	;
	; General purpose plot with attributes, we only fastpath
	; the simple case
	;
	clra
plot_loop:
	sta _vtrow
	ldb _vtattr
	cmpa #7			; Underline only applies on the bottom row
	beq ul_this
	andb #0xfd
ul_this:
	cmpa #3			; italic shift right for < 3
	blt ital_1
	andb #0xfb
	bra maskdone
ital_1:
	cmpa #5			; italic shift right for >= 5
	blt maskdone
	bitb #0x04
	bne maskdone
	orb #0x40		; spare bit borrow for bottom of italic
	andb #0xfb
maskdone:
	lda ,x+			; now throw the row away for a bit
	bitb #0x10
	bne notbold
	lsra
	ora -1,x		; shift and or to make it bold
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
	bitb #0x01		; inverse or not: we are really in inverse
	bne plot_inv		; by default so we complement except if
	coma			; inverted
plot_inv:
	bitb #0x20		; overstrike or plot ?
	bne overstrike
	sta ,y
	bra plotnext
overstrike:
	anda ,y
	sta ,y
plotnext:
	leay 32,y
	lda _vtrow
	inca
	cmpa #8
	bne plot_loop
	jmp _unmap_video	; tail call
;
; Fast path for normal attributes
;
plot_fast:
	leay 128,y		; saves time later keeping offsets 8-bit
	ldd ,x			; simple 8x8 renderer for now
	coma
	comb
	sta -128,y
	stb -96,y
	ldd 2,x
	coma
	comb
	sta -64,y
	stb -32,y
	ldd 4,x
	coma
	comb
	sta ,y
	stb 32,y
	ldd 6,x
	coma
	comb
	sta 64,y
	stb 96,y
	jmp _unmap_video	; tail call

;
;	void scroll_up(void)
;
_m6847_scroll_up:
	pshs u
	ldy #VIDEO_BASE
	leau 256,y
	jsr _map_video
vscrolln:
	; Unrolled line by line copy
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	pulu d,x
	std ,y++
	stx ,y++
	cmpu #VIDEO_END
	bne vscrolln
	jsr _unmap_video
	puls u,pc

;
;	void scroll_down(void)
;
_m6847_scroll_down:
	pshs u
	ldu #VIDEO_END
	leay -256,u
	jsr _map_video
vscrolld:
	; Unrolled line by line loop
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	ldx ,--y
	ldd ,--y
	pshu d,x
	cmpy #VIDEO_BASE
	bne vscrolld
	jsr _unmap_video
	puls u,pc

;
;	clear_across(int8_t y, int8_t x, uint16_t l)
;
_m6847_clear_across:
	tfr b,a
	ldb 2,s			; A := y, b := x
	jsr vidaddr		; Y now holds the address
	ldb 4,s			; Counter is in B
	jsr _map_video
	lda #0xff
	leay 128,y		; saves time later keeping offsets 8-bit
clearnext:
	sta -128,y
	sta -96,y
	sta -64,y
	sta -32,y
	sta ,y+
	sta 31,y
	sta 63,y
	sta 95,y
	decb
	bne clearnext
	jmp _unmap_video	; tail call

;
;	clear_lines(int8_t y, int8_t ct)
;
_m6847_clear_lines:
	tfr b,a			; A := y
	clrb
	jsr vidaddr		; y now holds ptr to line start
	ldb 2,s
	lslb
	lslb
	lslb
	jsr _map_video
	ldx #0xffff
wipel:
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	stx ,y++
	decb			; count of lines
	bne wipel
	jmp _unmap_video	; tail call

; void m6847_cursor_on(int8_t newy, int8_t newx);
_m6847_cursor_on:
	tfr b,a
	ldb 2,s			; A := newy, b := newx
	jsr vidaddr
	leax ,y
	stx cursor_save
	; Fall through
_m6847_cursor_off:
	ldb _vtattr
	bitb #0x80
	bne nocursor
	jsr _map_video
	ldx cursor_save
	leax 128,x		; saves time later keeping offsets 8-bit
	com -128,x
	com -96,x
	com -64,x
	com -32,x
	com ,x
	com 32,x
	com 64,x
	com 96,x
	jmp _unmap_video	; tail call
nocursor:
_m6847_cursor_disable:
	rts
_m6847_vtattr_notify:
	lda _vtattr
	anda #0x40		; VTA_ALTCHAR
	beq lowchar
        ldd #0xCA80
	bra setmode
lowchar:
        ldd #0xC47F
setmode:
	std plot_patch
	rts

;
;	These routines work in both 256x192x2 and 128x192x4 modes
;	because everything in the X plane is byte-wide.
;
_m6847_video_write:
	clra			; clr C
	bra tfr_cmd
_m6847_video_read:
	coma			; set C
	; fall through to tfr_cmd

;;; This does the job of READ & WRITE
;;;   takes: C = direction 0=write, 1=read
;;;   takes: X = transfer buffer ptr + 2
tfr_cmd:
	pshs cc,u		; save regs
	ldx 5,s
	orcc #0x10		; turn off interrupt - int might remap kernel
	lda #0x1f
	sta 0xff30		; unmap kernel above video memory
	ldd #0x80c0		; this is writing
	bcc L0			; if carry clear then keep D write
	exg a,b			; else flip D: now is reading
L0:	sta L1+1		; !!! self modify inner loop
	stb L1+3		; !!!
	bsr vidptr		; U = screen addr
	leay ,x			; Y = ptr to Height, width
	leax 4,x		; X = pixel data
	;; outer loop: iterate over pixel rows
L2:	lda 3,y			; count = width
	pshs u			; save screen ptr
	;; inner loop: iterate over columns
	;; modify mod+1 and mod+3 to switch directions
L1:	ldb ,x+			; get a byte from src
	stb ,u+			; save byte to dest
	deca			; bump counter
	bne L1			; loop
	;; increment outer loop
	puls u			; restore original screen ptr
	leau 32,u		; add byte span of screen (goto next line)
	dec 1,y			; bump row counter
	bne L2			; loop
	lda #KBANKV
	sta 0xff30		; remap kernel
	puls cc,u,pc		; restore regs, return
	

;
;	Find the address we need on a pixel row basis
;
vidptr:
	ldu #VIDEO_BASE
	ldd ,x++		; Y into B
	lda #32
	mul
	leau d,u
	ldd ,x++		; X
	leau d,u
	rts

; void m6847_video_cmd(uint8_t *ptr);
_m6847_video_cmd:
	tfr d,x
	pshs u
	jsr _map_video
	bsr vidptr		; u now points to the screen
nextline:
	pshs u			; save it for the next line
nextop:
	ldb ,x+			; op code, 0 = end of line
	beq endline
oploop:
	lda ,u			; do one screen byte
	anda ,x
	eora 1,x
	sta ,u+
	decb
	bne oploop		; keep going for run
	leax 2,x
	bra nextop		; next triplet
endline:
	puls u			; get position back
	leau 32,u		; down one scan line
	ldb ,x+			; get next op - 0,0 means end and done
	bne oploop
	jsr _unmap_video
	puls u,pc

	.commondata
cursor_save:
	.word 0
_vtrow:
	.byte 0
cc_video:
	.byte 0
