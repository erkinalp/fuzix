
;;; The ROM-resident fuzix loader for the CoCoSDC drive.  Mostly copied from
;;; Alan's IDE booter.

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

;;; Load a sector from SDC
;;;   takes: B - sector number, X = dest address
;;;   returns: nothing
load_block:
	clr @0x49		; put lba to sdc
	clr @0x4a		;
	stb @0x4b		;
	ldb #$80		; read sector op
	stb @0x48		; 
	exg x,x			; wait a few cycles for sdc status reg
	exg x,x			;   to be valid. - 2 long noops
	ldb #$2			; wait till sdc is ready
	;; FIXME: test for failure in this loop 
l_a:	bitb @0x48		;
	beq l_a
	;; tranfer data
	lda #128		; 128 x 16 bits = 256 byte sectors
	pshs a			; push count on stack
l_c:	ldd @0x4a		; get 16bit data from drive
	std ,x++		; stick it in memory
	dec ,s			; bump counter
	bne l_c			; repeat
	leas 1,s		; drop counter
	;; wait for return value
	ldb #$1
	;; FIXME: test for failure in the loop, also.
l_b:	bitb @0x48		;
	bne l_b			; wait for busy
	;; FIXME: get return status here and test?
	puls pc			; return



load_image:
	orcc #$50
	; COCO2 defaults to text at 0400-05FF move it to 0200
	ldx #0xFFC7
	clr ,x+			; Set F0
	clr ,x++		; Clear F1-F6
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	ldy #$0200			; display at this point
	lda #'G'		;
	sta ,y+
	ldd #$ff43		; set DP to io page
	tfr a,dp		; good for size + speed
	stb @0x40		; turn on SDC's LBA mode 
	;; we have to wait maybe 12us before doing anything
	;; with the SDC now, but the code below should
	;; delay SDC access enough.
	;; load kernel
	ldb #1			; start block no (* 2 for 256 byte sectors)
	lda #124		; number of blocks (* 2 for 256 bytes sectors)
	ldx #$0400		; dest address
load_loop:
	pshs a,b
	bsr load_block
	lda #'*'
	sta ,y+
	puls a,b
	incb
	deca
	bne load_loop
	ldx #0x0400
	lda ,x+
	cmpa #$15
	bne wrong_err
	lda ,x+
	cmpa #$C0
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
