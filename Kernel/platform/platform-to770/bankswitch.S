	.common

	.export __stub_1
	.export __stub_2
	.export __stub_3
	.export __bank_0_1
	.export __bank_0_2
	.export __bank_0_3
	.export __bank_1_2
	.export __bank_1_3
	.export __bank_2_1
	.export __bank_2_3
	.export __bank_3_1
	.export __bank_3_2

; From common spaces need to remember old bank setting

__stub_1:
__bank_0_1:
	clr 0x00		; switch to bank 0
bankout:
	lda kbank
	beq kret0
	deca
	beq kret1
	bra kret2
__stub_2:
__bank_0_2:
	clr 0x01
	bra bankout
__stub_3:
__bank_0_3:
	clr 0x02
	bra bankout
__bank_1_2:
	clr 0x01		; Switch to cartridge bank 1 (our 2)
kret0:
	jsr ,x			; call the handler
	clr 0x00
	rts
__bank_1_3:
	clr 0x02
	bra kret0
__bank_2_1:
	clr 0x00
kret1:
	jsr ,x
	clr 0x01
	rts
__bank_2_3:
	clr 0x02
	bra kret1
__bank_3_1:
	clr 0x00
kret2:
	jsr ,x
	clr 0x02
	rts
__bank_3_2:
	clr 0x01
	bra kret2
