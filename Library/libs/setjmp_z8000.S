/*
 *	setjmp / longjmp for Z8001 segmented mode
 *
 *	jmp_buf layout (10 words = 20 bytes):
 *	  [0]  R8
 *	  [1]  R9
 *	  [2]  R10
 *	  [3]  R11
 *	  [4]  R12
 *	  [5]  R13
 *	  [6]  R14 (SP segment)
 *	  [7]  R15 (SP offset)
 *	  [8]  PC segment (return address)
 *	  [9]  PC offset
 *
 *	Calling convention: first arg (jmp_buf pointer) at rr14(#4)
 *	Return address at rr14(#0) (4 bytes, pushed by CALL)
 */
	.segm
	.text

	.globl	_setjmp
	.globl	_longjmp

/*
 *	int setjmp(jmp_buf env)
 *	Returns 0 on direct call, val on longjmp return.
 */
_setjmp:
	ldl	rr2, rr14(#4)		! rr2 = pointer to jmp_buf

	/* Save callee-saved registers */
	ld	@rr2, r8
	inc	r3, #2
	ld	@rr2, r9
	inc	r3, #2
	ld	@rr2, r10
	inc	r3, #2
	ld	@rr2, r11
	inc	r3, #2
	ld	@rr2, r12
	inc	r3, #2
	ld	@rr2, r13
	inc	r3, #2

	/* Save stack pointer (caller's SP = current SP) */
	ld	@rr2, r14
	inc	r3, #2
	ld	@rr2, r15
	inc	r3, #2

	/* Save return address from stack.
	 * Z8001 CALL pushes: segment at lower addr, offset at higher.
	 *   rr14(#0) = PC segment, rr14(#2) = PC offset */
	ld	r0, rr14(#0)		! PC segment
	ld	@rr2, r0
	inc	r3, #2
	ld	r0, rr14(#2)		! PC offset
	ld	@rr2, r0

	/* Return 0 */
	clr	r2
	ret

/*
 *	void longjmp(jmp_buf env, int val)
 *	env at rr14(#4), val at rr14(#8)
 */
_longjmp:
	ldl	rr2, rr14(#4)		! rr2 = pointer to jmp_buf
	ld	r0, rr14(#8)		! r0 = val

	/* Ensure val is not 0 (POSIX: longjmp with val=0 returns 1) */
	test	r0
	jr	nz, _lj_ok
	inc	r0, #1
_lj_ok:

	/* Restore callee-saved registers */
	ld	r8, @rr2
	inc	r3, #2
	ld	r9, @rr2
	inc	r3, #2
	ld	r10, @rr2
	inc	r3, #2
	ld	r11, @rr2
	inc	r3, #2
	ld	r12, @rr2
	inc	r3, #2
	ld	r13, @rr2
	inc	r3, #2

	/* Read saved SP into rr4 */
	ld	r4, @rr2
	inc	r3, #2
	ld	r5, @rr2
	inc	r3, #2

	/* Read saved PC into rr6 */
	ld	r6, @rr2
	inc	r3, #2
	ld	r7, @rr2

	/* Restore SP, adjusted +4: setjmp saved the entry SP which
	 * still has its return address on the stack. After setjmp
	 * returned, SP was 4 higher. We need the post-return SP. */
	ldl	rr14, rr4
	add	r15, #4

	/* Set return value and jump to saved PC */
	ld	r2, r0
	jp	@rr6
