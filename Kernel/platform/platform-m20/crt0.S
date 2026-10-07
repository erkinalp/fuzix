/*
 *	Olivetti M20 startup code
 *
 *	The bootloader loads text to <<B>>:0000 and data to <<2>>:0200,
 *	then jumps here (<<B>>:0000 = _start).
 *	On entry we are in system mode with interrupts disabled.
 */

#include "../../cpu-z8000/kernel-z8000.def"

	.segm

	.globl	__end
	.globl	__bss_start
	.globl	_start
	.globl	_udata_block

	.text

_start:
	/* Disable interrupts */
	di	vi,nvi

	/*
	 * Set up system stack pointer (segmented RR14)
	 * Stack at top of first udata block in segment 2
	 */
	lda	rr14, _udata_block
	add	r15, #UBLOCK_SIZE

	/*
	 * Clear BSS (in segment 2, after .data)
	 * __bss_start and __end are segmented addresses
	 */
	lda	rr2, __bss_start
	lda	rr4, __end
	sub	r5, r3			! length in bytes (offset difference)
	jr	z, bss_done		! nothing to clear
	srl	r5, #1			! word count
	jr	z, bss_done
	clr	r0
bss_loop:
	ld	@rr2, r0
	inc	r3, #2			! increment offset only
	djnz	r5, bss_loop
bss_done:

	/* Call init_early */
	call	_init_early

	/* Call init_hardware */
	call	_init_hardware

	/* Call fuzix_main - should not return */
	call	_fuzix_main

	/* If we get here, halt */
	di	vi,nvi
_stop:
	halt
	jr	_stop
