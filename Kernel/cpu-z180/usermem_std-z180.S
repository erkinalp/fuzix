;
;	For the Z180 we use the DMA engine for user copies except for the
;	byte/word requests. At the moment we don't re-route any small
;	requests to the uget/uput API if they are below the DMA break even
;	point or just small.
;
;	The DMA engine stalls the CPU so the fact we di/ei around this does
;	not actually make much real difference. If DMA latency is a problem
;	then it needs doing in blocks here and in z180.s for fork() which is
;	by far the longer case.
;
;	TODO: consider BANKED support
;
	.z180

#include "../build/kernelu.def"
#include "../cpu-z180/z180.def"
#include "../cpu-z80u/kernel-z80.def"

        ; exported symbols
        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

	.code

OS_RAM1	.equ	FIRST_RAM_BANK + OS_BANK
;
;	Compute the DMA pages to use. This isn't quite as trivial as it
;	looks because the kernel common flips per process
;
;
;	Copy BC bytes from HL to DE using the DMA engine
;
dma_to_kernel:
	ld	a,0x02		; memory inc to memory inc
	out0	(DMA_DMODE),a
	push	bc
	ld	a,(_udata + U_DATA__U_PAGE)	; Bank code >> 4 is the upper 4 bits
	rra
	rra
	rra
	rra
	ld	c,a		; save src bank
	ld	b,a		; possible dst bank if common
	ld	a,d
	cp	>__common	; deal with common oddities
	jr	nc, dma_op
	ld	b, OS_RAM1 / 16
	jr	dma_op

dma_from_kernel:
	ld	a,0x02		; memory inc to memory inc
dma_user_fixed:
	out0	(DMA_DMODE),a	; burst mem to mem
	push bc
	ld	a,(_udata + U_DATA__U_PAGE)	; get our bank
	rra
	rra
	rra
	rra
	ld	c,a		; save src bank if common
	ld	b,a		; save dst bank
	ld	a,h
	cp	>__common
	jr	nc, dma_op
	ld	c, OS_RAM1 / 16	; not common
dma_op:
	; load banks
	out0	(DMA_SAR0B),c
	out0	(DMA_DAR0B),b
	; recover length
	pop	bc
	; load DMA engine addresses and length
	out0	(DMA_BCR0H),b
	out0	(DMA_BCR0L),c
	out0	(DMA_DAR0H),d
	out0	(DMA_DAR0L),e
	out0	(DMA_SAR0H),h
	out0	(DMA_SAR0L),l
	ld	a,0x40		; burst transfer
	out0	(DMA_DSTAT),a
	; DMA stalls the ret until done
	ret


uputget:
	ld	ix, 10
	add	ix, sp
        ; load DE with the byte count
        ld	c, (ix + 4) ; byte count
        ld	b, (ix + 5)
        ; load HL with the source address
        ld	l, (ix + 0) ; src address
        ld	h, (ix + 1)
        ; load DE with destination address (in userspace)
        ld	e, (ix + 2)
        ld	d, (ix + 3)
	; check if zero byte operation
	ld	a, b
	or	c
	di
	ret

__uput:
	push	ix
	ld	a,i
	push	af
	push	bc
	call	uputget		; source in HL dest in DE, count in BC
	; Z means nothing to copy
	call	nz, dma_from_kernel
upop:
	pop	bc
	pop	af
	pop	ix
	ld	hl, 0
	ret	po
	ei
	ret

__uget:
	push	ix
	ld	a,i
	push	af
	push	bc
	call	uputget		; source in HL dest in DE, count in BC
	call	nz, dma_to_kernel
	jr	upop

;
;	Write first byte to 0 then DMA it over
;

#if 0

__uzero:
	FIXME - BC save
	pop hl	; return
	pop de	; address
	pop bc	; size
	push bc
	push de
	push hl
	ld a, b	; check for 0 copy
	or c
	jr z,zerowipe
	ld hl,zerowipe+1	; just need a random zero byte
	ld a,0x0A		; memory const to memory inc
	ld a,i
	push af
	call dma_user_fixed
	pop af
	jp po,zerowipe
	ei
zerowipe:
	ld hl,0
	ret

#else

	.common
;
;	We don't use the DMA for this at the moment. Some debug is needed
;	there. It's also not clear it is a speed win anyway.
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
	ld	a, b	; check for 0 copy
	or	c
	jr	z, pop_out
	call	map_proc_always
	ld	(hl), 0
	dec	bc
	ld	a, b
	or	c
	jr	z, pop_out
	ld	e, l
	ld	d, h
	inc	de
	ldir
pop_out:
	pop	bc
	jp	map_kernel_restore

#endif

;
;	We need these in common as they bank switch
;
	.common
__uputc:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld	(hl), e
uputc_out:
	pop	bc
	jp	map_kernel_restore	; map the kernel back below common

__uputw:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld	(hl), e
	inc	hl
	ld	(hl), d
	jr	uputc_out

__ugetc:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
        ld	l, (hl)
	ld	h, 0
	jp	map_kernel_restore

__ugetw:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
        ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	map_kernel_restore
