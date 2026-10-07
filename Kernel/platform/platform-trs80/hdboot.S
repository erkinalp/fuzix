;
;	Hard disk boot block for the 4P. We have 256 bytes
;
	.abs
	.org 0

; If the byte CD appears in the boot then it'll go off on a bender
; and try and load a model III ROM image
;
; Must be under 128 bytes
hdboot:
	ld	a,0x87
	out	(0x84),a
	ld	hl,0x4300
	ld	de,0
	ld	bc,256
	ldir
	jp	go
go:	ld	hl,0x100
	ld	de,0x0004	; sector 4 track 0
next:
	ld	a,e
	out	(0xCB),a	; sector required
	ld	a,d
	out	(0xCE),a	; drive 0 head 0 256 bytes no ECC
	xor	a
	out	(0xCC),a	; cyl high is always 0
	out	(0xCD),a	; cyl low
	inc	a
	out	(0xCA),a	; 1 sector
	ld	a,0x20		; read
	out	(0xCF),a	; send command
wait:
	in	a,(0xCF)
	bit	6,a
	jr	z,wait		; wait for DRQ
	rra
	jr	c,error
	; Now do the data
	ld	bc,0xC8
	inir
	in	a,(0xCF);	; status
	rra
	jr	c,error
	inc	e		; sector ++
	bit 	5,e		; 32 ?
	jr	z,next
	ld	e,b		; B is 0 at this point
	inc	d
	bit	3,d		; 8 ?
	jr	z,next
	; We've loaded 8 tracks of 32 sectors minus 4 sectors into
	; memory
	jp	0x0100		; and launch
error:
	ld	a,0x86
	out	(0x84),a	; screen mapped
	ld	a,'E'
	ld	(0xF800),a	; E in top left
	di
	halt
