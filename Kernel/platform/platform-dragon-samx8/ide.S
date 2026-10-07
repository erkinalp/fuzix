;
;	Glenside style IDE block transfer logic
;

	.export _devide_read_data
	.export _devide_write_data

#include "kernel.def"

	.common

;
;	Standard mapping for Glenside style IDE
;
_devide_read_data:
	pshs dp
	tfr d,x
	lda #0xFF
	tfr a,dp
	jsr blkdev_rawflg
	leay 512,x
	sty endp
readword:
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	cmpx endp
	bne readword
	jsr blkdev_unrawflg
	puls dp,pc

_devide_write_data:
	pshs dp
	tfr d,x
	lda #0xFF
	tfr a,dp
	jsr blkdev_rawflg
	leay 512,x
	sty endp
writeword:
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	cmpx endp
	bne writeword
	jsr blkdev_unrawflg
	puls dp,pc

endp:	.word 0
