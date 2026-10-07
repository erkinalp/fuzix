;
; low-level routines for VC handling
;

	.export _set_vid_mode
	.export _set_vc_mode
	.export _vc_clear
	.export _vc_write_char
	.export _vc_read_char
	.export _vc_memset
	.export _vc_scroll_up
	.export _vc_scroll_down

#include "kernel.def"

	.common

; void set_vc_mode(uint8_t);
_set_vc_mode:
	; SAM V=0 (SG4)
	sta 0xffc0
	sta 0xffc2
	sta 0xffc4
	; SAMx8 base = (VC_BASE_ABS + B*512) / 32
	; = VC_FREG + B*16
	lslb
	lslb
	lslb
	lslb
	clra
	addd #VC_FREG
	std 0xff38
	; VDG mode 0 (SG4)
	lda 0xff22
	anda #0x07
	sta 0xff22
	rts

; void set_vid_mode(void);
_set_vid_mode:
	ldd #VIDEO_FREG
	std 0xff38
	jmp _vid256x192		; set resolution

; void vc_clear(int8_t vc_num);
_vc_clear:
	tfr b,a
	asla
	clrb
	ldx #VC_BASE+512
	leax d,x
	pshs x
	leax -512,x
	jsr _map_video
	ldd #0x2020
cllp:	std ,x++
	cmpx ,s
	blo cllp
	leas 2,s
	jmp _unmap_video

; void vc_write_char(unsigned char *, unsigned char);
_vc_write_char:
	tfr d,x
	ldb 2,s
	jsr _map_video
	stb ,x
	jmp _unmap_video

; char vc_read_char(unsigned char *);
_vc_read_char:
	tfr d,x
	jsr _map_video
	ldb ,x
	jmp _unmap_video

vtbase:	lda _curtty
	deca
	asla
	clrb
	ldx #VC_BASE
	leax d,x
	;leay 512,x
	rts

; void vc_scroll_up(void);
_vc_scroll_up:
	bsr vtbase
	leay 480,x
	pshs y
	leay 32,x
	jsr _map_video
scup:	ldd ,y++
	std ,x++
	cmpx ,s
	blo scup
	jsr _unmap_video
	puls d,pc

; void vc_scroll_down(void);
_vc_scroll_down:
	pshs u
	bsr vtbase
	leau 512,x
	leax 32,x
	stx ,s
	leax -32,u
	jsr _map_video
scdn:	ldd ,--x
	pshu d
	cmpx ,s
	bhi scdn
	jsr _unmap_video
	puls u,pc

; memset(), but with video memory mapped
; void vc_memset(unsigned char *, char, uint16_t);
_vc_memset:
	tfr d,x
	ldb 2,s
	ldy 3,s
	jsr _map_video
vcms:	stb ,x+
	leay -1,y
	bne vcms
	jsr _unmap_video
	rts

