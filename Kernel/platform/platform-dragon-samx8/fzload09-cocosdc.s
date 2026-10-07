; CoCoSDC core routines.
;
; SPDX-License-Identifier: CC0-1.0
;
; By Ciaran Anscomb, 2025-2026.  This file is dedicated to the public
; domain (Creative Commons "CC0 1.0 Universal"), but do note that this
; dedication may not apply to accompanying files.

; Provides:

; devopen
;
;   Call this first.  X register must contain the LSN of the next sector
;   to read.
;
; devclose
;
;  Call this when done.
;
; devread
;
;   Read next sector.

	.export devopen
	.export devclose
	.export devread

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; CoCoSDC registers

; Register definitions for CoCoSDC in DragonDOS mode.

CTRLATCH	equ 0xFF48	; controller latch (write)
CMDREG		equ 0xFF40	; command register (write)
STATREG		equ 0xFF40	; status register (read)
PREG1		equ 0xFF41	; param register 1
PREG2		equ 0xFF42	; param register 2
PREG3		equ 0xFF43	; param register 3
DATREGA		equ PREG2	; first data register
DATREGB		equ PREG3	; second data register

CMDMODE		equ 0x0B

; Status register masks
BUSY		equ 0x01
READY		equ 0x02
FAILED		equ 0x80

; Command values
CMDREAD		equ 0x80
CMDWRITE	equ 0xA0
CMDEX		equ 0xC0
CMDEXD		equ 0xE0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	.common

devopen:
	stx cocosdc_lsn,pcr
	; fall through
devclose:
	clr CTRLATCH
	rts

devread:
	pshs a,b,u
	pshs x
	ldd #(CMDMODE*256)|CMDREAD
	sta CTRLATCH		; enable cocosdc enhanced mode
	exg a,a			; delay
	exg a,a
	bsr cocosdc_while_busy
	clr PREG1		; 24-bit LSN (only use 16 bits)
	ldx cocosdc_lsn,pcr
	stx PREG2		; X is still LSN from above
	leax 1,x
	stx cocosdc_lsn,pcr
	stb CMDREG		; enhanced read sector
	exg a,a			; delay
	exg a,a
	puls x
drl10:	lda STATREG		; wait for READY flag
	bita #READY
	beq drl10
	lda #0x80		; 128 2-byte fetches
drl20:	ldu PREG2
	stu ,x++
	deca
	bne drl20
	bsr cocosdc_while_busy
	clr CMDREG
	puls a,b,u,pc

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Helpers

; Wait while CoCoSDC is BUSY.  On timeout, report error.
cocosdc_while_busy:
	pshs x
	ldx #0xE000		; timeout delay
cwbl10:	leax -1,x
	beq cwbl20
	lda STATREG
	lsra
	bcs cwbl10
	puls x,pc
cwbl20:	leas 2,s
	leax msg_busy,pcr
	lbra error

	.commondata

msg_busy:
	.byte 10
	.ascii "BUSY TIMEOUT"
	.byte 0

cocosdc_lsn:
	.word 0
