;
;	Bootstrap for cartridge start up. For now load from block 1 (second
;	block). We can refine this later. We do 62 block loads from block 1
;	for 0400 to 7FFF
;
;	Needs some kind of global timeout -> error handling
;
;
;	Load block b
;
	.export load_image

	.code

load_block:
	lda #0xFF
	tfr a,dp
load_block_1:
	lda #0x80
	bita @0x57			; busy
	bne load_block_1
	lda #0x40
	sta @0x56
load_block_2:
	lda #0x80
	bita @0x57			; busy
	bne load_block_2
	clr @0x55
	clr @0x54
	stb @0x53			; block number to fetch
	lda #1
	sta @0x52
	
	lda #0x40
wait_drdy:
	bita @0x57
	beq wait_drdy
	lda #0x20			; read command
	sta @0x57
	clrb
	lda #0x08
wait_drq:
	bita @0x57			; DRQ
	beq wait_drq
copyloop:
	lda @0x50			; read word and latch
	sta ,x+
	lda @0x58			; latched byte
	sta ,x+
	decb
	bne copyloop
	lda #0x80
wait_bsy:
	bita @0x57
	bne wait_bsy
	lda #0x01
	bita @0x57
	bne load_error
	rts


load_image:
	orcc #0x50
	; COCO2 defaults to text at 0400-05FF move it to 0200
	ldx #0xFFC7
	clr ,x+			; Set F0
	clr ,x++		; Clear F1-F6
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	ldx #0x0200			; display at this point
	ldd #0x6060
wiper:
	std ,x++
	cmpx #0x0400
	bne wiper
	ldy #0x0200
	lda #'G'
	sta ,y+
	ldb #1
	lda #62				; 31K straight load
	ldx #0x0400			; directly after video
load_loop:
	pshs a,b
	bsr load_block
	lda #'*'
	sta ,y+
	puls a,b
	incb
	deca
	bne load_loop

	ldx #0x0400			; check signature
	lda ,x+
	cmpa #0x15
	bne wrong_err
	lda ,x+
	cmpa #0xC0
	bne wrong_err
	rts

wrong_err:
	ldu #wrong
	bra l2
load_error:
	ldu #fail
l2:	bsr copy_str
l1:	bra l1

copy_str:
	lda ,u+
	beq endstr
	sta ,y+
	bra copy_str
endstr:	rts
fail:
	.ascii "FAIL"
	.byte 0
wrong:
	.ascii "WRONG IMAGE"
	.byte 0
