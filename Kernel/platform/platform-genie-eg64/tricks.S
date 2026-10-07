#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"
#include "../../lib/z80usingle.S"

;
;	We can't use the standard fast usermem copier because we map
;	I/O space into user for screen which overlaps some kernel data
;	space. Instead we must map specially so that when we do user copies
;	we map user but with I/O unmapped.
;

        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

;
;	We need these in common as they bank switch
;
	.common

;
;	The basic operations are copied from the standard one. Only the
;	blk transfers are different. uputget is a bit different as we are
;	not doing 8bit loop pairs.
;
__uputc:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_noio
	ld	(hl), e
uputc_out:
	jp	map_kernel	; map the kernel back below common

__uputw:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_noio
	ld	(hl), e
	inc	hl
	ld	(hl), d
	jp	map_kernel

__ugetc:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_noio
        ld	l, (hl)
	ld	h, #0
	jp	map_kernel

__ugetw:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_noio
        ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	map_kernel

; As our mapping covers both directions in one go these are the same
; routine
__uget:
__uput:
	push	bc
	push	ix
	ld	ix, 6
	add	ix, sp
        ld	c, (ix + 4)	; byte count
        ld	b, (ix + 5)
	ld	a, b
	or	c
	jr	z, uput_out	; no work
        ; load HL with the source address
        ld	l, (ix + 0) ; src address
        ld	h, (ix + 1)
        ; load DE with destination address (in userspace)
        ld	e, (ix + 2)
        ld	d, (ix + 3)
	call	map_proc_noio
	ldir
	call	map_kernel
uput_out:
	pop	ix
	pop	bc
	ld	hl, 0
	ret
;
__uzero:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ex	de,hl
	; Now zeroing BC bytes from HL
	ld	a, b	; check for 0 copy
	or	c
	jr	z,uz_out
	call	map_proc_noio
	ld	(hl), 0
	dec	bc
	ld	a, b
	or	c
	jr	z, uz_done
	ld	e, l
	ld	d, h
	inc	de
	ldir
uz_done:
	pop	bc
	jp	map_kernel
uz_out:
	pop	bc
	ret

