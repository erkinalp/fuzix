#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

;
;	RCBUS CF Adapter IDE
;

	.export _devide_read_data
	.export _devide_write_data
	.export iomap


	.common

;
;	Set up the mapping and registers for the I/O
;
iomap:
	tfr	d,x		; buffer
	lda	#0xFE
	tfr	a,dp
	ldb	#64		; length in words
	lda	_td_raw
	beq	kmap		; no separate buffer map
	suba	#1
	beq	proc
	lda	_td_page
	jmp	map_for_swap
proc:	jmp	map_proc_always
kmap:	rts

;
;	Standard mapping for IDE
;
_devide_read_data:
	pshs	dp
	jsr	iomap
readbyte:
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	lda	@IDEDATA
	sta	,x+
	decb
	bne	readbyte
	jsr	map_kernel
	puls	dp,pc

_devide_write_data:
	pshs	dp
	jsr	iomap
writebyte:
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	lda	,x+
	sta	@IDEDATA
	decb
	bne	writebyte
	jsr	map_kernel
	puls	dp,pc
