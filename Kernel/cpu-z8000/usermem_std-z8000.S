/*
 *	Z8001 user memory access routines
 *
 *	For a flat memory model without MMU these are simple copies.
 *	All addresses are segmented (32-bit seg:off).
 *
 *	GCC z8k-coff calling convention: args on stack, return in r2/rr2.
 *	After segmented CALL: rr14(#0)=PCoff, rr14(#2)=PCseg, rr14(#4)=arg1...
 */

	.segm
	.text

	.globl	__uputc
	.globl	__uputw
	.globl	__uputl
	.globl	__ugetc
	.globl	__ugetw
	.globl	__ugetl
	.globl	__uzero
	.globl	__uget
	.globl	__uput

/*
 *	int uputc(uint16_t val, void *uptr)
 *	val(16-bit) at rr14(#4), uptr(32-bit) at rr14(#6)
 */
__uputc:
	ld	r0, rr14(#4)		! val
	ldl	rr2, rr14(#6)		! uptr (seg:off)
	ldb	@rr2, rl0
	clr	r2			! return 0
	ret

/*
 *	int uputw(uint16_t val, void *uptr)
 *	val(16-bit) at rr14(#4), uptr(32-bit) at rr14(#6)
 */
__uputw:
	ld	r0, rr14(#4)		! val
	ldl	rr2, rr14(#6)		! uptr
	ld	@rr2, r0
	clr	r2			! return 0
	ret

/*
 *	int uputl(uint32_t val, void *uptr)
 *	val(32-bit) at rr14(#4), uptr(32-bit) at rr14(#8)
 */
__uputl:
	ldl	rr0, rr14(#4)		! val
	ldl	rr2, rr14(#8)		! uptr
	ldl	@rr2, rr0
	clr	r2			! return 0
	ret

/*
 *	uint16_t ugetc(void *uptr)
 *	uptr(32-bit) at rr14(#4), return in r2
 */
__ugetc:
	ldl	rr2, rr14(#4)		! uptr
	ldb	rl2, @rr2
	subb	rh2, rh2		! zero extend
	ret

/*
 *	uint16_t ugetw(void *uptr)
 *	uptr(32-bit) at rr14(#4), return in r2
 */
__ugetw:
	ldl	rr2, rr14(#4)		! uptr
	ld	r2, @rr2
	ret

/*
 *	uint32_t ugetl(void *uptr)
 *	uptr(32-bit) at rr14(#4), return in rr2
 */
__ugetl:
	ldl	rr2, rr14(#4)		! uptr
	ldl	rr2, @rr2
	ret

/*
 *	int uzero(void *uptr, uint16_t count)
 *	uptr(32-bit) at rr14(#4), count(16-bit) at rr14(#8)
 */
__uzero:
	ldl	rr2, rr14(#4)		! uptr
	ld	r4, rr14(#8)		! count
	test	r4
	jr	z, __uzero_done
	clr	r0
__uzero_loop:
	ldb	@rr2, rl0
	inc	r3, #1
	djnz	r4, __uzero_loop
__uzero_done:
	clr	r2			! return 0
	ret

/*
 *	int uget(void *uptr, void *kptr, uint16_t count)
 *	uptr(32-bit) at rr14(#4), kptr(32-bit) at rr14(#8), count at rr14(#12)
 */
__uget:
	pushl	@rr14, rr8		! save callee-saved
	ldl	rr2, rr14(#8)		! uptr (adjusted for push)
	ldl	rr4, rr14(#12)		! kptr
	ld	r8, rr14(#16)		! count
	test	r8
	jr	z, _uget_done
_uget_loop:
	ldb	rl0, @rr2
	ldb	@rr4, rl0
	inc	r3, #1
	inc	r5, #1
	djnz	r8, _uget_loop
_uget_done:
	clr	r2			! return 0
	popl	rr8, @rr14
	ret

/*
 *	int uput(void *kptr, void *uptr, uint16_t count)
 *	kptr(32-bit) at rr14(#4), uptr(32-bit) at rr14(#8), count at rr14(#12)
 */
__uput:
	pushl	@rr14, rr8		! save callee-saved
	ldl	rr2, rr14(#8)		! kptr (adjusted for push)
	ldl	rr4, rr14(#12)		! uptr
	ld	r8, rr14(#16)		! count
	test	r8
	jr	z, _uput_done
_uput_loop:
	ldb	rl0, @rr2
	ldb	@rr4, rl0
	inc	r3, #1
	inc	r5, #1
	djnz	r8, _uput_loop
_uput_done:
	clr	r2			! return 0
	popl	rr8, @rr14
	ret
