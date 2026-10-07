;
;	6809 version of the DS1302 support for RC2014
;

RTCREG		equ 0xFE0C

PIN_DATA_IN	equ 0x01
PIN_CE		equ 0x10
PIN_DATA_HIZ	equ 0x20
PIN_CLK		equ 0x40
PIN_DATA_OUT	equ 0x80

PIN_DATA_MASK	equ 0x7F00
PIN_CE_MASK	equ 0xEF00
PIN_CLK_MASK	equ 0xBF00

	.code

; -----------------------------------------------------------------------------
; DS1302 interface
; -----------------------------------------------------------------------------

	.export _ds1302_get_data

_ds1302_get_data:
	ldb RTCREG		; read input register
	clra
        andb #PIN_DATA_IN       ; mask off data pin
        rts

	.export _ds1302_set_driven

_ds1302_set_driven:
        lda _rtc_shadow
        anda #~PIN_DATA_HIZ	; 0 - output pin
	andb #1
	bne writereg
        ora #PIN_DATA_HIZ
writereg:
	sta RTCREG
	sta _rtc_shadow
	rts

	.export _ds1302_set_data

_ds1302_set_data:
        ldx #PIN_DATA_OUT+PIN_DATA_MASK
        bra setpin

	.export _ds1302_set_ce

_ds1302_set_ce:
        ldx #PIN_CE+PIN_CE_MASK
        bra setpin

	.export _ds1302_set_clk

_ds1302_set_clk:
        ldx #PIN_CLK+PIN_CLK_MASK
	; Fall through
setpin:
	clra
	exg d,x			; X is now the argument D the masks
        anda _rtc_shadow	; current & mask
	cmpx #0
	beq writereg
	stb ,-s			; no oraa b
        ora ,s+	 	        ; set if relevant
	bra writereg
