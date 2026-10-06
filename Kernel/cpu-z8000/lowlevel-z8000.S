/*
 *	Z8001 (segmented) low-level support for FUZIX
 *
 *	The Z8001 uses segmented addressing with 7-bit segment + 16-bit offset.
 *	Pointers are 32-bit: high word = segment, low word = offset.
 *	The SC (System Call) instruction is used for syscall entry.
 *	PSAP points to exception/interrupt vector table.
 *	System stack uses RR14 (R14=segment, R15=offset).
 *	Normal stack also uses RR14/R15 in normal mode.
 *
 *	Register conventions:
 *	  R10 = udata pointer (register global, preserved across calls)
 *	  RR14 = stack pointer (system or normal mode)
 *
 *	GCC z8k-coff calling convention (segmented, no -mregparms):
 *	  Arguments: passed on the stack, right-to-left
 *	  Return value: r2 (16-bit), rr2 (32-bit)
 *	  R0-R7: caller-saved
 *	  R8-R13: callee-saved
 *	  RR14: stack pointer (segmented pair)
 *
 *	After a segmented CALL, the stack contains:
 *	  rr14(#0): PC offset (2 bytes)
 *	  rr14(#2): PC segment (2 bytes)
 *	  rr14(#4): first argument
 *	  rr14(#6): second argument ...
 */

#include "kernel-z8000.def"

	.segm

	.globl	___hard_di
	.globl	___hard_ei
	.globl	___hard_irqrestore
	.globl	_doexec
	.globl	_get_usp
	.globl	_set_usp
	.globl	_outstring
	.globl	_outcharhex
	.globl	_vdso
	.globl	_udata_shadow
	.globl	_kernel_flag
	.globl	_copy_blocks
	.globl	_swap_blocks
	.globl	_sys_cpu
	.globl	_sys_cpu_feat
	.globl	_inb
	.globl	_outb
	.globl	_inw
	.globl	_outw
	.globl	_e_syscall
	.globl	_e_nvi
	.globl	_e_vi
	.globl	_e_nmi
	.globl	_e_ext_instr
	.globl	_e_priv_instr
	.globl	_e_segv
	.globl	_need_resched

	.text

/*
 *	I/O port access (Z8001 has separate I/O space)
 *	uint8_t inb(uint16_t port)
 *	port at rr14(#4), return in r2
 */
_inb:
	ld	r1, rr14(#4)		! port from stack
	inb	rl2, @r1
	subb	rh2, rh2		! zero extend
	ret

/*
 *	void outb(uint16_t port, uint8_t val)
 *	port at rr14(#4), val byte at rr14(#7)
 */
_outb:
	ld	r1, rr14(#4)		! port from stack
	ldb	rl0, rr14(#7)		! val byte from stack
	outb	@r1, rl0
	ret

/*
 *	uint16_t inw(uint16_t port)
 *	port at rr14(#4), return in r2
 */
_inw:
	ld	r1, rr14(#4)
	in	r2, @r1
	ret

/*
 *	void outw(uint16_t port, uint16_t val)
 *	port at rr14(#4), val at rr14(#6)
 */
_outw:
	ld	r1, rr14(#4)		! port
	ld	r0, rr14(#6)		! value
	out	@r1, r0
	ret

/*
 *	Interrupt control
 *
 *	irqflags_t ___hard_di(void)
 *	Returns previous FCW interrupt bits in r2
 *
 *	Z8001 FCW bit layout:
 *	  Bit 15: SEG (segmented mode, read-only on Z8001)
 *	  Bit 14: S/N (System/Normal mode)
 *	  Bit 13: EPA (Extended Processing Architecture enable)
 *	  Bit 12: VIE (Vectored Interrupt Enable)
 *	  Bit 11: NVIE (Non-Vectored Interrupt Enable)
 *	  Bits 10-0: flags (C, Z, S, P/V, DA, H)
 */
___hard_di:
	ldctl	r2, fcw
	ld	r1, r2
	and	r1, #0xE7FF		! clear VIE (bit 12) and NVIE (bit 11)
	ldctl	fcw, r1
	and	r2, #0x1800		! return only VIE+NVIE bits
	ret

/*
 *	void ___hard_ei(void)
 */
___hard_ei:
	ei	vi,nvi
	ret

/*
 *	void ___hard_irqrestore(irqflags_t flags)
 *	flags at rr14(#4)
 */
___hard_irqrestore:
	ld	r1, rr14(#4)		! flags from stack (VIE+NVIE bits)
	ldctl	r0, fcw
	and	r0, #0xE7FF		! clear VIE (bit 12) and NVIE (bit 11)
	or	r0, r1			! restore saved VIE+NVIE
	ldctl	fcw, r0
	ret

/*
 *	Get/set user stack pointer (normal mode SP)
 *	The Z8001 LDCTL can access the normal stack pointer from system mode.
 */
_get_usp:
	ldctl	r2, nspseg
	ldctl	r3, nspoff
	ret				! returns seg:off in rr2

/*
 *	void set_usp(uint32_t sp)
 *	sp (seg:off) at rr14(#4)
 */
_set_usp:
	ld	r0, rr14(#4)		! segment
	ld	r1, rr14(#6)		! offset
	ldctl	nspseg, r0
	ldctl	nspoff, r1
	ret

/*
 *	System call entry point
 *
 *	On Z8001, the SC instruction pushes on the system stack:
 *	  +0: SC instruction word (identifier, contains SC #n)
 *	  +2: FCW (saved)
 *	  +4: PC segment
 *	  +6: PC offset
 *
 *	User passes syscall number in R1, args as 32-bit pairs:
 *	  RR2 (R2:R3) = argn
 *	  RR4 (R4:R5) = argn1
 *	  RR6 (R6:R7) = argn2
 *	For 16-bit args, user sets high word to 0 (e.g. clr r2; ld r3, #fd).
 *	Return value in RR2 (to match C convention).
 */
_e_syscall:
	/* Save RR10 (udata pointer register pair) - must be first for fork */
	pushl	@rr14, rr10
	ldl	rr10, _udata_shadow

	ldb	(0x82000000+U_DATA__U_CALLNO)(r11), rl1	! syscall number
	ldb	(0x82000000+U_DATA__U_INSYS)(r11), #1

	/* Save 32-bit arguments.
	   arg_t is 32-bit, stored as two 16-bit words (big-endian).
	   U_DATA__U_ARGN is the offset of the high word. */
	ld	rr10(#U_DATA__U_ARGN), r2
	ld	rr10(#U_DATA__U_ARGN+2), r3
	ld	rr10(#U_DATA__U_ARGN1), r4
	ld	rr10(#U_DATA__U_ARGN1+2), r5
	ld	rr10(#U_DATA__U_ARGN2), r6
	ld	rr10(#U_DATA__U_ARGN2+2), r7

	/* Save user stack pointer */
	ldctl	r0, nspseg
	ldctl	r1, nspoff
	ldl	rr10(#U_DATA__U_SYSCALL_SP), rr0

	ldb	_kernel_flag, #1
	ei	vi,nvi			! enable interrupts for syscall

	call	_unix_syscall

	di	vi,nvi

	ldb	(0x82000000+U_DATA__U_INSYS)(r11), #0
	ldb	_kernel_flag, #0

	/* Check for errors */
	ld	r1, rr10(#U_DATA__U_ERROR)
	test	r1
	jr	nz, sysc_err

	ldl	rr2, rr10(#U_DATA__U_RETVAL)
	jr	sysc_sig

sysc_err:
	ld	r2, #-1
	ld	r3, #-1

sysc_sig:
	testb	(0x82000000+U_DATA__U_CURSIG)(r11)
	jr	nz, return_via_signal

	/* Normal return - pop RR10 and do IRET */
	popl	rr10, @rr14
	iret

return_via_signal:
	/*
	 * Signal delivery from syscall return.
	 *
	 * At entry:
	 *   rr2 = syscall return value
	 *   rr10 = udata pointer, r11 = udata offset
	 *   Kernel stack (rr14 ->):
	 *     +0:  saved rr10 (4)
	 *     +4:  SC identifier (2)
	 *     +6:  FCW (2)
	 *     +8:  PC seg (2) = original user return
	 *     +10: PC off (2)
	 *
	 * Signal frame on user stack (20 bytes):
	 *     +0:  VDSO unwind addr seg (2)
	 *     +2:  VDSO unwind addr off (2)
	 *     +4:  signal number (2)
	 *     +6:  padding (2)
	 *     +8:  saved r2 (2)
	 *     +10: saved r3 (2)
	 *     +12: original PC seg (2)
	 *     +14: original PC off (2)
	 *     +16: old NSP seg (2)
	 *     +18: old NSP off (2)
	 *
	 * Kernel stack after saves (rr14 ->):
	 *     +0:  saved rr8 (4)   — callee-saved, clobbered for NSP read
	 *     +4:  saved rr2 (4)   — syscall return value
	 *     +8:  saved rr10 (4)
	 *     +12: SC identifier (2)
	 *     +14: FCW (2)
	 *     +16: PC seg (2)
	 *     +18: PC off (2)
	 */

	/* Save syscall return value and callee-saved rr8 on kernel stack */
	pushl	@rr14, rr2
	pushl	@rr14, rr8

	/* Read signal number and clear u_cursig */
	ldb	rl0, (0x82000000+U_DATA__U_CURSIG)(r11)
	subb	rh0, rh0
	ldb	(0x82000000+U_DATA__U_CURSIG)(r11), #0

	/* Get handler: u_sigvec[sig] (4 bytes per entry) */
	ld	r1, r0
	sla	r1, #2
	ldl	rr4, rr10
	add	r5, #U_DATA__U_SIGVEC
	add	r5, r1
	ldl	rr6, @rr4		! rr6 = handler address

	/* Get current user NSP */
	ldctl	r8, nspseg
	ldctl	r9, nspoff		! rr8 = old user NSP

	/* Build signal frame (push downward using rr4 as write ptr) */
	ldl	rr4, rr8

	/* old NSP */
	sub	r5, #2
	ld	@rr4, r9
	sub	r5, #2
	ld	@rr4, r8

	/* original PC (from IRET frame: rr8 at +0, rr2 at +4, rr10 at +8,
	   identifier at +12, FCW at +14, PC_seg at +16, PC_off at +18) */
	ld	r1, rr14(#18)
	sub	r5, #2
	ld	@rr4, r1
	ld	r1, rr14(#16)
	sub	r5, #2
	ld	@rr4, r1

	/* saved r3, r2 (syscall return, at rr14+4..+7) */
	ld	r1, rr14(#6)
	sub	r5, #2
	ld	@rr4, r1
	ld	r1, rr14(#4)
	sub	r5, #2
	ld	@rr4, r1

	/* signal number + padding */
	sub	r5, #2
	ld	@rr4, #0
	sub	r5, #2
	ld	@rr4, r0

	/* return address = codebase + 4 (VDSO signal unwind) */
	ldl	rr2, rr10(#U_DATA__U_CODEBASE)
	add	r3, #4
	sub	r5, #2
	ld	@rr4, r3
	sub	r5, #2
	ld	@rr4, r2

	/* Update user NSP */
	ldctl	nspseg, r4
	ldctl	nspoff, r5

	/* Patch IRET frame PC to signal handler */
	ld	rr14(#16), r6
	ld	rr14(#18), r7

	/* Restore rr8 (callee-saved), discard saved rr2, restore rr10, IRET */
	popl	rr8, @rr14
	popl	rr2, @rr14
	popl	rr10, @rr14
	iret


/*
 *	Execute a user process
 *
 *	doexec(uaddr_t addr)
 *	addr (seg:off) at rr14(#4)
 */
_doexec:
	ldl	rr2, rr14(#4)		! entry point from stack

	/* Reset supervisor stack to top of udata block */
	ldl	rr14, _udata_shadow		! load segmented SP from current udata
	add	r15, #UBLOCK_SIZE

	ldb	_kernel_flag, #0
	ldb	(0x82000000+U_DATA__U_INSYS)(r11), #0

	/* Set user stack pointer */
	ldl	rr0, rr10(#U_DATA__U_ISP)
	ldctl	nspseg, r0
	ldctl	nspoff, r1

	/* Build an IRET frame on system stack:
	 *   The IRET frame (bottom to top of stack):
	 *     PC offset  (lowest address)
	 *     PC segment
	 *     FCW
	 *     Identifier (highest address, popped first)
	 */
	push	@rr14, r3		! PC offset
	push	@rr14, r2		! PC segment
	ld	r0, #0x9800		! FCW: SEG=1, S/N=0(normal), VIE=1, NVIE=1
	push	@rr14, r0
	clr	r0			! identifier
	push	@rr14, r0

	/* Clear user-visible registers */
	clr	r0
	clr	r1
	clr	r2
	clr	r3
	clr	r4
	clr	r5
	clr	r6
	clr	r7
	clr	r8
	clr	r9
	/* R10 = udata, leave it for now - will be cleared in user VDSO */
	clr	r11
	clr	r12
	clr	r13

	iret			! jump to user space

/*
 *	VDSO - copied into the base of each user executable
 *	Provides the syscall entry point and signal return stub
 */
_vdso:
	sc	#0			! system call trap (offset 0, 4 bytes)
	ret
_vdso_sigreturn:			! signal unwind (offset 4)
	! Entry: handler just did 'ret', popping the return address.
	! Stack: [sig(4)] [r2(2)] [r3(2)] [PC_seg(2)] [PC_off(2)] [old_NSP(4)]
	add	r15, #4			! skip signal number arg
	pop	r2, @rr14		! restore syscall return r2
	pop	r3, @rr14		! restore syscall return r3
	popl	rr4, @rr14		! original PC into rr4
	popl	rr6, @rr14		! old NSP into rr6
	ldl	rr14, rr6		! restore user stack pointer
	jp	@rr4			! return to interrupted code

/*
 *	Exception handlers
 */
_e_ext_instr:
	/* Extended/unimplemented instruction trap */
	call	_trap_monitor
	iret

_e_priv_instr:
	/* Privileged instruction in normal mode */
	call	_trap_monitor
	iret

_e_segv:
	/* Segment violation */
	call	_trap_monitor
	iret

/*
 *	NVI handler (timer interrupt on M20)
 */
_e_nvi:
	pushl	@rr14, rr0
	pushl	@rr14, rr2
	pushl	@rr14, rr4
	pushl	@rr14, rr6
	pushl	@rr14, rr10

	ldl	rr10, _udata_shadow
	ldb	(0x82000000+U_DATA__U_ININTERRUPT)(r11), #1

	call	_plt_interrupt

	ldb	(0x82000000+U_DATA__U_ININTERRUPT)(r11), #0

	testb	(0x82000000+U_DATA__U_INSYS)(r11)
	jr	nz, nvi_no_preempt

	testb	_need_resched
	jr	z, nvi_no_preempt

	/* Preemption */
	ldl	rr2, rr10(#U_DATA__U_PTAB)
	ldb	rl0, (0x82000000+P_TAB__P_STATUS_OFFSET)(r3)
	cpb	rl0, #P_RUNNING
	jr	nz, nvi_no_ready
	ldb	(0x82000000+P_TAB__P_STATUS_OFFSET)(r3), #P_READY
	ldb	rl0, (0x82000000+P_TAB__P_FLAGS_OFFSET)(r3)
	orb	rl0, #PFL_BATCH
	ldb	(0x82000000+P_TAB__P_FLAGS_OFFSET)(r3), rl0
nvi_no_ready:
	call	_switchout

nvi_no_preempt:
	testb	(0x82000000+U_DATA__U_CURSIG)(r11)
	jr	nz, nvi_signal

	popl	rr10, @rr14
	popl	rr6, @rr14
	popl	rr4, @rr14
	popl	rr2, @rr14
	popl	rr0, @rr14
	iret

nvi_signal:
	/* TODO: deliver signal on return from interrupt */
	popl	rr10, @rr14
	popl	rr6, @rr14
	popl	rr4, @rr14
	popl	rr2, @rr14
	popl	rr0, @rr14
	iret

/*
 *	VI handler (vectored interrupts via i8259A)
 */
_e_vi:
	pushl	@rr14, rr0
	pushl	@rr14, rr2
	pushl	@rr14, rr4
	pushl	@rr14, rr6
	pushl	@rr14, rr10

	ldl	rr10, _udata_shadow
	ldb	(0x82000000+U_DATA__U_ININTERRUPT)(r11), #1

	call	_plt_interrupt

	! Send non-specific EOI to i8259A PIC
	ldb	rl0, #0x20
	outb	#0x0041, rl0

	ldb	(0x82000000+U_DATA__U_ININTERRUPT)(r11), #0

	popl	rr10, @rr14
	popl	rr6, @rr14
	popl	rr4, @rr14
	popl	rr2, @rr14
	popl	rr0, @rr14
	iret

/*
 *	NMI handler
 */
_e_nmi:
	iret

/*
 *	Debug output helpers
 *	These call _outchar which expects its arg on the stack.
 */
_outstring:
	/* rr2 = pointer to string (segmented), at rr14(#4) */
	ldl	rr2, rr14(#4)
_outstring_loop:
	ldb	rl0, @rr2
	testb	rl0
	ret	z
	push	@rr14, r0		! push char as word arg
	call	_outchar
	pop	r0, @rr14		! clean stack
	inc	r3, #1
	jr	_outstring_loop

_outcharhex:
	/* print byte at rr14(#5) as hex */
	push	@rr14, r7		! save caller-saved we use
	ldb	rl7, rr14(#7)		! load byte arg (4 ret + 2 push + 1)
	ldb	rl0, rl7
	srlb	rl0, #4			! high nibble
	subb	rh0, rh0
	call	_hexnibble_out
	ldb	rl0, rl7
	andb	rl0, #0x0F		! low nibble
	subb	rh0, rh0
	call	_hexnibble_out
	pop	r7, @rr14
	ret

_hexnibble_out:
	addb	rl0, #0x30
	cpb	rl0, #0x3A
	jr	lt, _hexnib_ok
	addb	rl0, #7
_hexnib_ok:
	push	@rr14, r0		! push char arg for outchar
	call	_outchar
	pop	r0, @rr14		! clean stack
	ret

/*
 *	Block copy/swap helpers
 *	copy_blocks(void *dst, void *src, unsigned int count)
 *	dst(32-bit) at rr14(#4), src(32-bit) at rr14(#8), count at rr14(#12)
 */
_copy_blocks:
	pushl	@rr14, rr8		! save callee-saved
	ldl	rr2, rr14(#8)		! dst (adjusted for pushed rr8)
	ldl	rr4, rr14(#12)		! src
	ld	r6, rr14(#16)		! count
	test	r6
	jr	z, _copy_done
_copy_loop:
	ld	r8, #256		! 256 words = 512 bytes
_copy_word:
	ld	r0, @rr4
	ld	@rr2, r0
	inc	r3, #2
	inc	r5, #2
	djnz	r8, _copy_word
	djnz	r6, _copy_loop
_copy_done:
	popl	rr8, @rr14
	ret

/*
 *	swap_blocks(void *ptr1, void *ptr2, unsigned int count)
 *	ptr1(32-bit) at rr14(#4), ptr2(32-bit) at rr14(#8), count at rr14(#12)
 */
_swap_blocks:
	pushl	@rr14, rr8		! save callee-saved
	ldl	rr2, rr14(#8)		! ptr1 (adjusted for pushed rr8)
	ldl	rr4, rr14(#12)		! ptr2
	ld	r6, rr14(#16)		! count
	test	r6
	jr	z, _swap_done
_swap_loop:
	ld	r8, #256
_swap_word:
	ld	r0, @rr2
	ld	r1, @rr4
	ld	@rr2, r1
	ld	@rr4, r0
	inc	r3, #2
	inc	r5, #2
	djnz	r8, _swap_word
	djnz	r6, _swap_loop
_swap_done:
	popl	rr8, @rr14
	ret

	.data

_udata_shadow:
	.long	0			! segmented pointer to current udata
	.globl	_udata_ptr_seg
_udata_ptr_seg:
	.long	0			! segmented base for stack reset
_kernel_flag:
	.byte	0
! need_resched is defined in main.c
_sys_cpu:
	.byte	0
_sys_cpu_feat:
	.byte	0
