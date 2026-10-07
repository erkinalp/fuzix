;
; Tinydisk helper functions
;

	; exported
	.export blkdev_rawflg
	.export blkdev_unrawflg

	.common

;;; Helper for blkdev drivers to setup memory based on rawflag
;;; WARNING: the blk_op struct will not be available for rawflag=1/2 after calling this!
blkdev_rawflg:
	pshs b			; save regs
	ldb _td_raw		; 0 = kernel 1 = user 2 = swap
	decb			; compare to 1
	bmi out			; less than or equal: 0, or 1 don't do map
	beq proc		; is direct to process
	; is swap so map page into kernel memory at 0x0000
	ldb _td_page		; get page no for swap
	stb 0xff34		; task 1, kernel task regs.
	puls b,pc
proc:	jsr map_proc_always
	; get parameters from C, X points to cmd packet
out:	puls b,pc

;;; Helper for blkdev drivers to clean up memory after blkdev_rawflg
blkdev_unrawflg:
	clr 0xff34
	jmp map_kernel		; tail call
