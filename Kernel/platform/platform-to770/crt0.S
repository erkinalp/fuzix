;
;	ROM header (linked at 0)
;
	.overlay1

	.ascii " Fuzix For Thomson TO  "
	.byte	0x04		; end of name
	.word	0
	.byte	0xE1		; checksum
	.byte	0x00
	.word	coldboot
	.word	warmboot

coldboot:
warmboot:
	lda	#0xE7
	tfr	a,dp
	orcc	#0x50
	;	Cartridge bank 0 is 0000-3FFF
	;	Map the rest as we want it
	lda	#$F0	; page 2
	sta	@0xC9

	clra
	clrb
	ldx	#0x4000
wipes:
	std	,x++
	cmpx	#0x6000
	bne	wipes

	; Set the video map to the other bank
	lda	@0xC3
	anda	#0xFE
	sta	@0xC3

	ldd	#0x0707
	ldx	#0x4000
wipesc:
	std	,x++
	cmpx	#0x6000
	bne	wipesc

	; Set the video back to the bitmap
	lda	@0xC3
	anda	#0xFE
	sta	@0xC3

	; Next job - get the shared code into the right place
	ldx	#0x3E00	; copy 6100-62FF
	ldu	#0x6100
cpshare:
	ldd	,x++
	std	,u++
	cmpx	#0x4000
	bne	cpshare

	; Second page is the bootstrap page first is the shared work
	; space
	jmp	bootstrap

	.abs
	.org	0xE200

	; Will jump into this during bootstrap
bootstrap:
	lda	#0	; TODO bank 3
	sta	@0xC9
	ldx	#0
	ldu	#0xA000
hiseg:	ldd	,x++
	std	,u++
	cmpx	#0x4000
	bne	hiseg

	lda	#0xF0	; TODO bank 0
	sta	@0xC9

	jmp	bootcont

	.overlay1
bootcont:
	; We now have the 256 byte stub block set up correctly
	; and the upper memory is set up correctly
	lds	#kstack_top
	ldx	#__bss
	ldy	#__bss_size
	clra
bss_wipe:
	sta	,x+
	leay	-1,y
	bne	bss_wipe
	; These must be in overlay 1
	jsr	init_early
	jsr	init_hardware
	; and into discard
	pshs	d
	jsr	_fuzix_main
	puls	d
	orcc	#0x50
stop:	bra	stop

	.commondata

	.export stub
	.export stub_end

stub:
	.ds 600
stub_end:
