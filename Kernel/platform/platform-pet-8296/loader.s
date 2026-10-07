;
;	We are loaded at $0200.
;	0000-7FFF are RAM 8000-FFFF ROM (except Video and I/O)
;
;	We switch to all RAM and then load an image from 0400-FDFF
;	and then jump to 0x0402 if the marker is right
;
;  0xFFF0 memory control byte
;  BIT 
;  0 - 1 = WriteProtect $8000 - $BFFF
;  1 - 1 = WriteProtect $C000 - $FFFF
;  2     0 0:  2 and 0,  0 1:  2 and 1
;  3     1 0:  3 and 0,  1 1:  3 and 1
;  4 - 1 = reserved
;  5 - 1 = Screen peek $8000-$8FFF 
;  6 - 1 = I/O peek $E800-$EFFF  
;  7 - 1 = enable memory expansion
;
; to read io enable i/o peek, to write i/o enable i/o peek and write protect $c000
; to read video enable video peek, to write video enable video peek AND write protect $8000
; 
START = $0800
ENABLE    = $80
IO_PEEK   = $40
VID_PEEK  = $20
KERN_PAGE = $00 
USER_PAGE = $06

CR0		  = $FFF0
VIA		  = $E840
IDE		  = $FF80
; pet kernel char out routine (only availble when roms are mapped in!)
chrout  = $FFD2 

	.zeropage
ptr1:	.res	2
sector:	.res	1

	.segment "CODE"

	.byte $65
	.byte $02
start:
	; set the full 64K to RAM
	; enable ram_on AND ram_9 by setting via pa0, pa1 and pa2 to zero
	; assume our IDE port does not care
	SEI ; disable interrupts
	lda VIA+3
	ORA #7
	sta VIA+3
	LDA VIA+1
	AND #$F8
	STA VIA+1
	; set cr0  to zero
	LDA $00
	sta CR0
	; now we should have ram except at $8000 and $FF80 - $FF8F 

	LDA #$00	
	sta ptr1
	lda #$08	
	sta ptr1+1

	lda #$01	; 0 is the partition/boot block
	sta sector

	jsr waitready
	lda #$E0
	sta IDE+6	; Make sure we are in LBA mode
dread:
	jsr waitready
	lda sector
	cmp #$7C	; loaded all of the image ?
	beq load_done
	inc sector
	sta IDE+3
	lda #$01
	sta IDE+2	; num sectors (drives may clear this each I/O)
	jsr waitready
	lda #$20
	sta IDE+7	; read command

	jsr waitdrq

	ldy #0
bytes1:
	lda IDE
	sta (ptr1),y
	iny
	bne bytes1
	inc ptr1+1
bytes2:
	lda IDE
	sta (ptr1),y
	iny
	bne bytes2
	inc ptr1+1
	jmp dread

load_done:
	lda START
	cmp #$02
	bne bad_load
	lda START+1
	cmp #$65
	bne bad_load

; we cant overwrite the ide registers and only load multiples of 512, 
; so stop at fe00 and copy 0x10 bytes from fdf0 byte
; to the vector table
    ldx #$10
@rep1:
	lda $fdf0,X
	sta $fff0,x
	dex 
	bne @rep1
	jmp START+2

bad_load:
    ; enable rom
	LDA #7
	ORA VIA+1
	STA VIA+1
	; geht nicht weil alles gelöscht
;	ldx #>badimg
;	lda #<badimg
;	JSR outstring
	jmp ($fffc)	
	
	lda IDE+6
	jsr outcharhex
	lda IDE+5
	jsr outcharhex
	lda IDE+4
	jsr outcharhex
	lda IDE+3
	jsr outcharhex
stop:
	jmp stop

waitready:
	lda IDE+7
	and #$40
	beq waitready
	rts

waitdrq:
	lda IDE+7
	and #$09
	beq waitdrq
	and #$01
	beq wait_drq_done
	lda IDE+1
	jsr outcharhex
	jmp bad_load

wait_drq_done:
	rts

outstring:
	sta ptr1
	stx ptr1+1
	ldy #0
outstringl:
	lda (ptr1),y
	cmp #0
	beq outdone1
	jsr outchar
	iny
	jmp outstringl

outcharhex:
	tax
	ror
	ror
	ror
	ror
	jsr outcharhex1
	txa
outcharhex1:
	and #$0F
	clc
	adc #'0'
	cmp #'9'+1
	bcc outchar
	adc #7
outchar:
outcharw:
    jsr chrout
outdone1:
	rts
badimg:
	.byte 13,10,"Image not bootable."
running:
	.byte 13,10,0
