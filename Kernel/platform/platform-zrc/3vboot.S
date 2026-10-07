;
;	3vZ80 512 byte SD loader
;
;	Copyright 2026 Alan Cox
;
;	Redistribution and use in source and binary forms, with or without
;	modification, are permitted provided that the following conditions
;	are met:
;
;	1. Redistributions of source code must retain the above copyright
;	notice, this list of conditions and the following disclaimer.
;
;	2. Redistributions in binary form must reproduce the above copyright
;	notice, this list of conditions and the following disclaimer in the
;	documentation and/or other materials provided with the distribution.
;
;	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;	“AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;	A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;	HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
;	LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;
	.abs
	.org	0x8000

start:
buf:
	ld	hl,0
	ld 	de,0x8000
	ld	bc,512
	ldir
	jp	go
go:
	ld	sp,0xFE00
	ld	ix,cmd17
	ld	a,'*'
	out	(0x81),a
	ld	bc,0x0869	; 8 bits port 69
	exx
	call	csraise
	ld	b,20
csloop:	call	sendff
	djnz	csloop
	ld	hl,cmd0
	call	sendcmd
	dec	a
	jr	nz,fail
	ld	hl,cmd8
	call	sendcmd
	dec	a
	jr	nz,oldcard
newcard:
	call	get4
	ld	hl,(buf + 2)
	ld	de,0xAA01		; 01AA but big endian
	or	a
	sbc	hl,de
	jr	nz, fail
wait41:
	ld	hl,acmd41
	call	sendacmd
	jr	nz, wait41
	ld	hl,cmd58
	call	sendcmd
	jr	nz, fail
	call	get4
	ld	a,(buf)
	and	0x40
	jr	loadit		; SDv2 A = 0x40 is block mode
oldcard:
	ld	hl,acmd41_0
	call	sendacmd
	cp	2
	jr	nc,mmc
wait41_0:
	ld	hl,acmd41_0
	call	sendacmd
	jr	nz,wait41_0
	jr	secsize
mmc:
	ld	hl,cmd1
	call	sendcmd
	; Card is MMC
secsize:
	ld	hl,cmd16
	call	sendcmd
	jr	nz, fail
	; Entered with A = 0 if byte addressed, 0x40 if not
loadit:
	or	a
	jr	nz,doload	; Is in block
	; These must not affect flags
	ld	(ix+2),0x02	; Sector 120h byte offset
	ld	(ix+3),0x3E	; will bump to 40 before read
	ld	(ix+4),0x00	; low 8bits
doload:
	ex	af,af'		; Save the type in AF'
	ld	hl,0
	ld	d,0x80
loadnext:
	push	hl
	ld	a,'.'
	call	chout
	ld	hl,cmd17
	call	nextsec
	call	sendcmd
	jr	nz, fail
waitdata:
	call	sendff
	cp	0xFE
	jr	nz,waitdata
	ld	b,0
	pop	hl
dloop:
	call	sendff
	ld	(hl),a
	inc	hl
	call	sendff
	ld	(hl),a
	inc	hl
	djnz	dloop
	; We now have a sector
	; Have we crossed to 0x8000
	bit	7,h
	jr	z, loadnext	; Not yet - next sector
	inc	d		; Incremement bank count
	ld	a,d
	cp	0x8F		; Are we done ?
	jr	z, boot		; yes->go
	out	(0x1F),a	; next bank
	ld	h,0		; back to 0
	ld	a,13
	call	chout
	ld	a,10
	call	chout
	jr	loadnext	; and off we go again
boot:	xor	a
	out	(0x1F),a	; bank 0
	ld	a,'@'
	call	chout
	rst	0		; and go
nextsec:
	ex	af,af'
	jr	z,bytemode
	ex	af,af'
	inc	(ix+4)
	ret	nz
	inc	(ix+3)
	ret
bytemode:
	ex	af,af'
	inc	(ix+3)
	inc	(ix+3)
	ret	nz
	inc	(ix+2)
	ret

sendacmd:
	push	hl
	ld	hl,cmd55
	call	sendcmd
	pop	hl
sendcmd:
	call	csraise
	call	cslower
	ld	a,l
	cp	<cmd0
	jr	z,nowaitff
waitff:	call	sendff
	inc	a
	jr	nz,waitff
nowaitff:
	ld	b,6
sendlp:
	ld	a,(hl)
	call	send
	inc	hl
	djnz	sendlp
	call	sendff
waitret:
	call	sendff
	bit	7,a
	jr	nz,waitret
	or	a
	ret
get4:
	ld	b,4
	ld	hl,buf
get4l:
	call	sendff
	ld	(hl),a
	inc	hl
	djnz	get4l
	ret

cslower:
	exx
	ld	hl,0xF7E7	; data high clock high/low
	ld	de,0xF6E6	; data low clock high/low
	exx
	ld	a,0xF7		; All high except CS
	out	(0x69),a
	ret
csraise:
	exx
	ld	hl,0xFFEF	; data high clock high/low
	ld	de,0xFEEE	; data low clock high/low
	exx
	ld	a,0xFF		; All high
	out	(0x69),a
sendff:
	exx
	push	de
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	out	(c),l		; 1 bit and low
	out	(c),h		; 1 bit and high
	in	a,(c)
	rla
	rl	d
	ld	a,d
	or	a
	pop	de
	exx
	ret

send:
	exx
	ld	b,8
txloop:
	rla
	jr	nc,tx0
	out	(c),l
	out	(c),h
	djnz	txloop
	exx
	ret
tx0:
	out	(c),e
	out	(c),d
	djnz	txloop
	exx
	ret

fail:
	ld	a,'E'
	out	(0x81),a
	di
	halt

chout:	push	af
chw:	in	a,(0x80)
	and	2
	jr	z,chw
	pop	af
	out	(0x81),a
	ret

cmd0:
	.byte	0x40,0x00,0x00,0x00,0x00,0x95
cmd1:
	.byte	0x41,0x00,0x00,0x00,0x00,0x01
cmd8:
	.byte	0x48,0x00,0x00,0x01,0xAA,0x87
cmd16:
	.byte	0x50,0x00,0x00,0x02,0x00,0x01
cmd17:
	.byte	0x51,0x00,0x00,0x01,0x1F,0x01	; sector 0x120 next in block mode
cmd55:
	.byte	0x77,0x00,0x00,0x00,0x00,0x01
cmd58:
	.byte	0x7A,0x00,0x00,0x00,0x00,0x01
acmd41_0:
	.byte	0x69,0x00,0x00,0x00,0x00,0x01
acmd41:
	.byte	0x69,0x40,0x00,0x00,0x00,0x01
