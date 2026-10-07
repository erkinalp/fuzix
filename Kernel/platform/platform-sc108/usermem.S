;
;	We have a custom implementation of usermem. We really need
;	to optimize ldir_to/from_user.
;
#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

        ; exported symbols
        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

	.common
uputget:
        ; load DE with the byte count
        ld c, (ix + 8) ; byte count
        ld b, (ix + 9)
	ld a, b
	or c
	ret z		; no work
        ; load HL with the source address
        ld l, (ix + 4) ; src address
        ld h, (ix + 5)
        ; load DE with destination address
        ld e, (ix + 6)
        ld d, (ix + 7)
	ret

__uget:
	push ix
	ld ix,#0
	add ix, sp
	push bc
	call uputget
	jr z, uget_out
	push de
	pop ix
	call ldir_from_user
uget_out:
	pop bc
	pop ix
	ld hl,#0
	ret

__uput:
	push ix
	ld ix,#0
	add ix,sp
	push bc
	call uputget
	jr z, uget_out
	push de
	pop ix
	call ldir_to_user
	jr uget_out

;
;	The kernel IRQ code will restore the bank if it interrupts this
;	logic
;
__uzero:
	push bc
	ld hl,4
	add hl,sp
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)
	ld a,b
	or c
	jr z,uout
	ex de,hl
	ld a,#0x81
	out (0x38),a		; user bank
	rlca
	out (0x30),a
	ld (hl),0
	dec bc
	ld a,b
	or c
	jr z, uoutbc
	ld e,l
	ld d,h
	inc de
	ldir
uoutbc:
	ld a,1
	out (0x38),a
	rlca
	out (0x30),a
	pop bc
	ret


__ugetc:
	pop de
	pop hl
	push hl
	push de
	ld a,#0x81
	out (0x38),a
	rlca
	out (0x30),a
	ld l,(hl)
	ld h,0
uout:
	ld a,1
	out (0x38),a
	rlca
	out (0x30),a
	ret

__ugetw:
	pop de
	pop hl
	push hl
	push de
	ld a,0x81
	out (0x38),a
	rlca
	out (0x30),a
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	jr uout
	
__uputc:
	ld hl,2
	add hl,sp
	ld e,(hl)
	inc hl
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,0x81
	out (0x38),a
	rlca
	out (0x30),a
	ld (hl),e
	jr uout

__uputw:
	ld hl,2
	add hl,sp
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld a,(hl)
	inc hl
	ld h,(hl)
	ld l,a
	ld a,0x81
	out (0x38),a
	rlca
	out (0x30),a
	ld (hl),e
	inc hl
	ld (hl),d
	jr uout
