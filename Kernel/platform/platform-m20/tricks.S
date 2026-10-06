/*
 *	Context switching for Z8001 flat memory model
 *
 *	Adapted for Z8001 segmented addressing.
 *	Stack pointer is RR14 (R14=segment, R15=offset).
 *	All push/pop use @rr14.
 *	All indirect memory access uses register pairs (rr2, rr4...).
 *	R0 cannot be used as a base register.
 *
 *	GCC z8k-coff: args on stack, return in r2/rr2.
 */

#include "../../cpu-z8000/kernel-z8000.def"

	.segm

	.globl	_plt_switchout
	.globl	_switchin
	.globl	_dofork
	.globl	_udata_shadow

	.text

/*
 *	Switchout saves the current process state and calls getproc
 *	to find a new process to run, then calls switchin.
 *
 *	Stack frame after saves (16 bytes + 4 byte return addr):
 *	  SP+0:  rr12
 *	  SP+4:  rr10
 *	  SP+8:  rr8
 *	  SP+12: rr0 (user NSP seg:off)
 *	  SP+16: return address (caller of plt_switchout)
 */
_plt_switchout:
	di	vi,nvi

	/* Save callee-saved registers and user SP on kernel stack */
	ldctl	r0, nspseg
	ldctl	r1, nspoff
	pushl	@rr14, rr0		! save user SP (seg:off)
	pushl	@rr14, rr8
	pushl	@rr14, rr10		! includes udata ptr RR10
	pushl	@rr14, rr12

	/* Save kernel SP in udata */
	ldl	rr10(#U_DATA__U_SP), rr14

	/* Find another process to run */
	call	_getproc

	/* switchin(p) - getproc returns ptptr in rr2 */
	pushl	@rr14, rr2		! push arg for switchin
	call	_switchin

	/* Should never return */
	jp	_plt_monitor

/*
 *	switchin(ptptr p)
 *	Switch to process p. Argument (32-bit ptr) at rr14(#4).
 */
_switchin:
	di	vi,nvi

	ldl	rr2, rr14(#4)		! get process pointer from stack

	/* Get the udata pointer for this process */
	ldl	rr10, rr2(#P_TAB__P_UDATA_OFFSET)

	/* Verify u_ptab matches */
	ldl	rr6, rr10(#U_DATA__U_PTAB)
	cpl	rr6, rr2
	jr	nz, switchinfail

	/* Update shadow */
	ldl	_udata_shadow, rr10

	/* Restore kernel SP */
	ldl	rr14, rr10(#U_DATA__U_SP)

	/* Mark process as running */
	ldb	(0x82000000+P_TAB__P_STATUS_OFFSET)(r3), #P_RUNNING

	/* Swap user memory if needed (for fork copy-on-write) */
	clr	r4
	clr	r5			! death = 0
	pushl	@rr14, rr4		! arg 2: death
	pushl	@rr14, rr2		! arg 1: ptptr p
	call	_pagemap_switch
	addl	rr14, #8		! clean args

	/* Reload rr10 — pagemap_switch may have clobbered it */
	ldl	rr10, _udata_shadow

	/* Restore callee-saved registers */
	popl	rr12, @rr14
	popl	rr10, @rr14		! restores RR10 (udata ptr) from saved
	popl	rr8, @rr14
	popl	rr0, @rr14		! user SP (seg:off)
	ldctl	nspseg, r0
	ldctl	nspoff, r1

	/* Clear runticks */
	clr	_runticks

	testb	(0x82000000+U_DATA__U_ININTERRUPT)(r11)
	jr	nz, keepoff

	ei	vi,nvi

keepoff:
	clr	r2			! return 0
	ret

switchinfail:
	call	_plt_monitor

/*
 *	dofork(ptptr child)
 *	child (32-bit ptr) at rr14(#4)
 *
 *	Based on the 68000 flat port approach:
 *	1. Copy parent udata block to child
 *	2. Call makeproc to set up child p_tab
 *	3. Build a forkreturn frame at the top of the child's stack
 *	   that does IRET directly to user space (bypassing unix_syscall)
 *	4. Return child PID to parent
 */
_dofork:
	pushl	@rr14, rr8
	pushl	@rr14, rr12

	ldl	rr2, rr14(#12)		! child p_tab (adjusted for 2 pushes)
	pushl	@rr14, rr2		! save child p_tab

	/* Get child udata pointer */
	ldl	rr4, rr2(#P_TAB__P_UDATA_OFFSET)

	/*
	 * Copy parent udata block to child (UBLOCK_SIZE bytes).
	 * Source = rr10 (parent udata), dest = rr4 (child udata).
	 */
	ldl	rr8, rr10		! rr8 = source (parent udata)
	ldl	rr12, rr4		! rr12 = dest (child udata)
	ld	r2, #UBLOCK_SIZE
_copy_udata:
	ldb	rh0, @rr8
	ldb	@rr12, rh0
	inc	r9, #1
	inc	r13, #1
	dec	r2, #1
	jr	nz, _copy_udata

	/*
	 * Call makeproc(child_ptab, child_udata)
	 */
	popl	rr2, @rr14		! child p_tab
	pushl	@rr14, rr2		! save again
	ldl	rr4, rr2(#P_TAB__P_UDATA_OFFSET)	! child udata
	pushl	@rr14, rr4		! arg 2: child udata
	pushl	@rr14, rr2		! arg 1: child p_tab
	call	_makeproc
	addl	rr14, #8		! clean args

	/* Reload parent udata pointer */
	ldl	rr10, _udata_shadow

	/*
	 * Build a forkreturn frame in the child's udata stack.
	 * Like the 68000 port: the child will IRET directly to user
	 * space from forkreturn, bypassing unix_syscall.
	 *
	 * The parent's IRET frame from the SC instruction is at
	 * the top of the udata block:
	 *   udata+UBLOCK_SIZE-8: identifier (2)
	 *   udata+UBLOCK_SIZE-6: FCW (2)
	 *   udata+UBLOCK_SIZE-4: PC seg (2)
	 *   udata+UBLOCK_SIZE-2: PC off (2)
	 *
	 * We build this in the child's stack (growing down from top):
	 *   [IRET frame: identifier, FCW, PC_seg, PC_off] (8 bytes)
	 *   [saved rr10 for popl before iret] (4 bytes)
	 *   [return address = forkreturn] (4 bytes)
	 *   [user SP seg:off] (4 bytes)
	 *   [dummy rr8] (4 bytes)
	 *   [saved rr10 = child udata ptr] (4 bytes)
	 *   [dummy rr12] (4 bytes)
	 *   ← child u_sp points here
	 *
	 * switchin pops: rr12, rr10, rr8, rr0(userSP), then ret→forkreturn
	 * forkreturn: clears regs, pops rr10, iret → user space
	 */
	popl	rr2, @rr14		! child p_tab
	ldl	rr4, rr2(#P_TAB__P_UDATA_OFFSET)	! child udata
	pushl	@rr14, rr2		! save child p_tab

	/* rr8 = pointer to build the frame, start at child udata + UBLOCK_SIZE */
	ldl	rr8, rr4
	add	r9, #UBLOCK_SIZE

	/*
	 * Copy IRET frame from parent's stack top.
	 * Parent IRET at rr10 + UBLOCK_SIZE - 8 (copied to child already,
	 * so read from child at rr4 + UBLOCK_SIZE - 8).
	 * Actually, we already copied the whole block — the IRET frame
	 * is already at the right place in the child's block.
	 * rr8 points to child udata + UBLOCK_SIZE = top.
	 * The IRET frame is at rr8 - 8.
	 * We leave it in place and build below it.
	 */

	/* Below the IRET frame: push saved rr10 for the popl before iret */
	sub	r9, #8			! skip past IRET frame
	sub	r9, #2
	ld	@rr8, r5		! child udata offset
	sub	r9, #2
	ld	@rr8, r4		! child udata segment

	/* Push return address = forkreturn */
	lda	rr12, _forkreturn
	sub	r9, #2
	ld	@rr8, r13		! forkreturn offset
	sub	r9, #2
	ld	@rr8, r12		! forkreturn segment

	/* Push user SP (copy from parent's NSP) */
	ldctl	r0, nspseg
	ldctl	r1, nspoff
	sub	r9, #2
	ld	@rr8, r1		! NSP offset
	sub	r9, #2
	ld	@rr8, r0		! NSP segment

	/* Push dummy rr8 (user's r8-r13 are saved/restored by the
	 * userspace _fork wrapper on the user stack, not here) */
	sub	r9, #4
	ldl	rr12, #0
	ldl	@rr8, rr12

	/* Push child rr10 (udata pointer) */
	sub	r9, #2
	ld	@rr8, r5		! child udata offset
	sub	r9, #2
	ld	@rr8, r4		! child udata segment

	/* Push dummy rr12 */
	sub	r9, #4
	ldl	rr12, #0
	ldl	@rr8, rr12

	/* Set child's u_sp to current rr8 position */
	ldl	rr4(#U_DATA__U_SP), rr8

	/* Mark child not in syscall */
	ldb	(0x82000000+U_DATA__U_INSYS)(r5), #0

	/* Return child PID to parent */
	popl	rr2, @rr14		! child p_tab
	ld	r2, rr2(#P_TAB__P_PID_OFFSET)

	clr	_runticks

	popl	rr12, @rr14
	popl	rr8, @rr14
	ret

/*
 *	Child process resumes here from switchin.
 *	switchin popped: rr12, rr10(child udata), rr8, rr0(user SP)
 *	and set NSP. Then ret jumped here.
 *
 *	Above us on the stack: [saved rr10][IRET frame]
 *	We pop rr10 and IRET directly to user space with r2=0.
 */
_forkreturn:
	clr	_runticks
	clr	r0
	clr	r1
	clr	r2			! fork returns 0 to child
	clr	r3
	clr	r4
	clr	r5
	clr	r6
	clr	r7
	! r8-r13 are callee-saved: restored by switchin from frame
	! rr10 will be popped below
	popl	rr10, @rr14		! restore rr10 from frame
	iret				! return to user space
