;;;
;;;  The CoCoSDC Driver
;;;    Big thanks for Darren Atkinson for good documentation
;;;    and help with autodetection in the init method
;;;
;;;

;;; exported
	.export _devsdc_write
	.export _devsdc_read

;;; dev

#ifdef CONFIG_SDC_DRAGONDOS
;;; Hardware addressing (DragonDOS mode)
CTRLATCH	equ 0xff48	; controller latch (write)
CMDREG		equ 0xff40	; command register (write)
STATREG		equ 0xff40	; status register (read)
PREG1		equ 0xff41	; param register 1
PREG2		equ 0xff42	; param register 2
PREG3		equ 0xff43	; param register 3
#else
;;; Hardware addressing (RSDOS mode)
CTRLATCH	equ 0xff40	; controller latch (write)
CMDREG		equ 0xff48	; command register (write)
STATREG		equ 0xff48	; status register (read)
PREG1		equ 0xff49	; param register 1
PREG2		equ 0xff4a	; param register 2
PREG3		equ 0xff4b	; param register 3
#endif
DATREGA		equ PREG2	; first data register
DATREGB		equ PREG3	; second data register

	.common


;;; Write 256 bytes to SDC
; void devsdc_write(unsigned char *addr);
_devsdc_write:
	pshs u
	tfr d,x
	ldy #PREG2		; set Y to point at data reg a
	ldd #64*256+4		; A = chunk count (64), B = bytes per chunk (4)
	jsr blkdev_rawflg	; map memory based on blkopt flag
wrChnk:	ldu ,x			; get 2 data bytes from source
	stu ,y			; send data to controller
	ldu 2,x			; two more bytes..
	stu ,y			; ..for this chunk
	abx			; increment X by chunk size (4)
	deca			; decrement loop counter
	bne wrChnk		; loop until all chunks written
	jsr blkdev_unrawflg	; reset memory
	puls u,pc		; return

;;; Reads 256 bytes from SDC
; void devsdc_read(unsigned char *addr);
_devsdc_read:
	pshs u
	tfr d,x
	ldy #PREG2		; set Y to point to data reg a
	ldd #32*256+8		; A = chunk count (32), B = bytes per chunk (8)
	jsr blkdev_rawflg	; map memory based on blkopt flag
rdChnk:	ldu ,y			; read 1st pair of bytes for the chunk
	stu ,x			; store to buffer
	ldu ,y			; bytes 3 and 4 of..
	stu 2,x			; ..the chunk
	ldu ,y			; bytes 5 and 6 of..
	stu 4,x			; ..the chunk
	ldu ,y			; bytes 7 and 8 of..
	stu 6,x			; ..the chunk
	abx			; increment X by chunk size (8)
	deca			; decrement loop counter
	bne rdChnk		; loop if more chunks to read
	jsr blkdev_unrawflg	; reset memory
	puls u,pc		; return
