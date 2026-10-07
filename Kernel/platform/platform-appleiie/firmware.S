;
;	Driver routines for firmware interfaces
;
#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.export _pascal_op
	.export _pascal_cmd
	.export _dos_op
;
;	Issue pascal command X to slot A. Note that we don't check for valid
;	firmware here. That was done earlier. If it's not valid we jump to
;	fishkill.
;
_pascal_op:
	stx cmdbyte		; patch the operation data following the jsr
	clc
	adc #$C0		; Turn slot into slot address high
	sta @tmp+1		; xxFF holds the index to the DOS entry
	lda #255
	sta @tmp
	ldy #0
	lda (@tmp),y		; index
	clc
	adc #3			; and 3 beyond that (next JMP) is the pascal
	sta @tmp		; one.
	jsr gotmp		; Fake a jsr (@tmp)
cmdbyte:
	.byte $00
	.word _pascal_cmd+1
	rts

gotmp:	jmp (tmp)

;
;	Issue a generic ProDOS command block
;
_dos_op:
	clc
	adc #$C0
	sta @tmp+1
	lda #255
	sta @tmp
	ldy #0
	lda (@tmp),y
	sta @tmp
	jmp (@tmp)

;
;	The caller loads up to 9 bytes of data into this buffer
;
	.bss
_pascal_cmd:	.ds 9


