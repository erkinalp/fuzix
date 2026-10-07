;
;	RAM disc helpers for DivIDE Plus
;
;	We will make even COMMONMEM vanish whilst we work!
;

	.commondata

	.export _rd_io

	.export _rd_wr
	.export _rd_dptr
	.export _rd_page
	.export _rd_addr


_rd_io:
	push	bc
	di
	ld	a,(_rd_page)
	call	map_bank_a
	ld	hl,(_rd_addr)
	ld	de,(_rd_dptr)
	ld	bc,512
	ld	a,(_rd_wr)
	or	a
	jr	z, is_wr
do_io:
	ldir
	call	map_kernel_restore
	ld	a,(_int_disabled)
	or	a
	ret	nz
	ei
	ret
is_wr:
	ex	de,hl
	jr	do_io

_rd_wr:
	.byte	0
_rd_dptr:
	.word	0
_rd_page:
	.byte	0
_rd_addr:
	.word	0
