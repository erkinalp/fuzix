;
;	Loaded at 0x200
;
	.abs
	.org 0x200

	movp	%0x06,p0xC4	; RTS low OUT1 low (ROM off)
;
;	Load LBA 2 upwards into 0x400-0xFFFF
;
	mov	%0x04, r2
	clr	r3
	mov	%0x02, r4

wrdy1:	btjzp	%0x40,p0x97,wrdy1
	mov	r4,a
	movp	a,p0x93		; Set LBA
	movp	%1,p0x92	; May have been cleared by command
wrdy2:	btjzp	%0x40,p0x97,wrdy2
	movp	%0x20,p0x97

wdrq:	btjzp	%0x08,p0x97,wdrq
	; Now input 512 bytes
	clr	b
rdloop:
	movp	p0x90,a
	sta	*r3
	inc	r3
	djnz	b,rdloop
	inc	r2
rdloop2:
	movp	p0x90,a
	sta	*r3
	inc	r3
	djnz	b,rdloop2
wch1:	btjzp	%0x20,p0xC5,wch1
	movp	%'.',p0xC0
	inc	r4
	inc	r2
	jnz	wrdy1

	; Loaded up to 0xFFFE/FF so transfer control
wch2:	btjzp	%0x20,p0xC5,wch2
	movp	%13,p0xC0
wch3:	btjzp	%0x20,p0xC5,wch3
	movp	%10,p0xC0
	br	@0x0500

