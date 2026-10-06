/*
 *	Olivetti M20 platform-specific assembly
 *
 *	Z8001 segmented mode
 */

#include "../../cpu-z8000/kernel-z8000.def"

	.segm

	.globl	_plt_reboot
	.globl	_init_early
	.globl	_init_hardware
	.globl	_program_vectors
	.globl	_plt_interrupt
	.globl	_plt_idle
	.globl	_outchar
	.globl	_plt_monitor

	.globl	_crt_put
	.globl	_trap_monitor

/*
 *	M20 I/O port addresses
 */
#define	TTY_DATA	0x00C1		/* i8251A serial data */
#define	TTY_CTRL	0x00C3		/* i8251A serial control/status */
#define	PIT_C0		0x0121		/* i8253 counter 0 (TTY baud) */
#define	PIT_C2		0x0125		/* i8253 counter 2 (system timer) */
#define	PIT_CTRL	0x0127		/* i8253 control */
#define	PIC_CMD		0x0041		/* i8259A command */
#define	PIC_DATA	0x0043		/* i8259A data/mask */

	.text

_plt_monitor:
_trap_monitor:
_plt_reboot:
	di	vi,nvi
	ldl	rr12, #0x8400008C	! BIOS cold_boot entry
	jp	@rr12

_init_early:
	/*
	 * Set up udata pointer in R10 and shadow.
	 * Also set _udata_ptr_seg for doexec's SP reset.
	 */
	lda	rr10, _udata_block
	ldl	_udata_shadow, rr10
	ldl	_udata_ptr_seg, rr10	! defined in lowlevel-z8000.S
	ret

_plt_idle:
	ei	vi,nvi
	halt
	ret

_init_hardware:
	/*
	 *	Initialize i8251A TTY USART
	 *	Must reset and configure before use — BIOS state
	 *	may not survive the boot process.
	 */
	ldb	rl0, #0x00
	outb	#TTY_CTRL, rl0		! sync byte 1
	outb	#TTY_CTRL, rl0		! sync byte 2
	outb	#TTY_CTRL, rl0		! sync byte 3
	ldb	rl0, #0x40		! internal reset
	outb	#TTY_CTRL, rl0
	ldb	rl0, #0xCE		! mode: async, 8N1, x16 clock
	outb	#TTY_CTRL, rl0
	ldb	rl0, #0x37		! command: RTS, DTR, error reset, RxEN, TxEN
	outb	#TTY_CTRL, rl0
	inb	rl0, #TTY_DATA		! flush pending data

	/*
	 *	Set up PIT counter 0 for TTY serial baud rate
	 *	Baud = 1230782 / (16 * divisor)
	 *	For 9600: divisor = 8 (gives 9609 baud, close enough)
	 */
	ldb	rl0, #0x36		! Counter 0, LSB then MSB, mode 3
	outb	#PIT_CTRL, rl0
	ldb	rl0, #0x08		! LSB of divisor 8
	outb	#PIT_C0, rl0
	ldb	rl0, #0x00		! MSB of divisor 8
	outb	#PIT_C0, rl0

	/*
	 *	Set up PIT counter 2 for system timer (NVI)
	 *	~50 Hz: divisor = 1230782 / 50 = 24616 = 0x6028
	 */
	ldb	rl0, #0xB4		! Counter 2, LSB then MSB, mode 2
	outb	#PIT_CTRL, rl0
	ldb	rl0, #0x28		! LSB of 0x6028
	outb	#PIT_C2, rl0
	ldb	rl0, #0x60		! MSB of 0x6028
	outb	#PIT_C2, rl0

	/*
	 *	Initialize i8259A PIC
	 */
	ldb	rl0, #0x13		! ICW1: single, edge, ICW4 needed
	outb	#PIC_CMD, rl0
	ldb	rl0, #0x00		! ICW2: vector offset 0
	outb	#PIC_DATA, rl0
	ldb	rl0, #0x01		! ICW4: 8086 mode
	outb	#PIC_DATA, rl0
	ldb	rl0, #0xFF		! Mask all interrupts for now
	outb	#PIC_DATA, rl0

	/*
	 *	Set up PSAP to point to our vector table at <<2>>:0100
	 *	Must be done with interrupts disabled (they already are)
	 */
	ld	r0, #0x8200		! segment 2
	ldctl	psapseg, r0
	ld	r0, #0x0100		! offset 0x100 (256-byte aligned)
	ldctl	psapoff, r0

	/*
	 *	Fill PSAP entries with handler addresses.
	 *	NVI MUST be set up before the PIT timer fires.
	 *
	 *	PSAP layout (8 bytes per entry):
	 *	  +0: reserved (identifier)
	 *	  +2: FCW for handler
	 *	  +4: PC segment
	 *	  +6: PC offset
	 *
	 *	Offsets from PSAP base:
	 *	  0x00: reserved
	 *	  0x08: extended instruction trap
	 *	  0x10: privileged instruction trap
	 *	  0x18: system call (SC)
	 *	  0x20: segmentation trap
	 *	  0x28: NMI
	 *	  0x30: NVI (timer)
	 *	  0x38+: vectored interrupts
	 */
	/*
	 * PSAP table is at <<2>>:0100 (set by ldctl psapoff above).
	 * Fill all entries BEFORE the PIT timer starts generating NVI.
	 *
	 * Each entry is 8 bytes: reserved(2), FCW(2), PC_seg(2), PC_off(2)
	 * We use r0=FCW, r1=segment for all entries.
	 */
	ld	r2, #0x8200		! segment 2
	ld	r3, #0x0100		! offset 0x100
	ld	r0, #0xC000		! FCW: VIE+NVIE (matches BIOS)
	ld	r1, #0x8B00		! PC segment B (kernel code)

	! Extended instruction trap (offset 0x08)
	ld	rr2(#0x0A), r0
	ld	rr2(#0x0C), r1
	lda	rr4, _e_ext_instr
	ld	rr2(#0x0E), r5

	! Privileged instruction trap (offset 0x10)
	ld	rr2(#0x12), r0
	ld	rr2(#0x14), r1
	lda	rr4, _e_priv_instr
	ld	rr2(#0x16), r5

	! System call handler (offset 0x18)
	ld	rr2(#0x1A), r0
	ld	rr2(#0x1C), r1
	lda	rr4, _e_syscall
	ld	rr2(#0x1E), r5

	! Segmentation trap (offset 0x20)
	ld	rr2(#0x22), r0
	ld	rr2(#0x24), r1
	lda	rr4, _e_segv
	ld	rr2(#0x26), r5

	! NMI handler (offset 0x28)
	ld	rr2(#0x2A), r0
	ld	rr2(#0x2C), r1
	lda	rr4, _e_nmi
	ld	rr2(#0x2E), r5

	! NVI handler (offset 0x30) — CRITICAL: PIT timer fires here
	ld	rr2(#0x32), r0
	ld	rr2(#0x34), r1
	lda	rr4, _e_nvi
	ld	rr2(#0x36), r5

	! VI handlers — vectored interrupts (offset 0x38, 8 entries)
	! PIC ICW2=0x00 so IR0=vec0, IR1=vec1, ..., IR7=vec7
	! Each entry at PSAP + 0x38 + (vec * 8)
	lda	rr4, _e_vi
	ld	r6, #8			! 8 vectors
	ld	r7, #0x3A		! starting offset
_vi_fill:
	ld	rr2(r7), r0		! FCW
	inc	r7, #2
	ld	rr2(r7), r1		! PC segment
	inc	r7, #2
	ld	rr2(r7), r5		! PC offset
	inc	r7, #4			! skip to next entry (reserved word)
	djnz	r6, _vi_fill

	/* Set memory size */
	ld	_ramsize, #512		! 512 KB
	ld	_procmem, #384		! rough estimate for user space

	ret

/*
 *	Interrupt dispatcher
 */
_plt_interrupt:
	call	_timer_interrupt
	call	_tty_interrupt
	ret

/*
 *	Program exception vectors
 */
_program_vectors:
	ret

/*
 *	No banking - all stubs are no-ops
 */
	.globl	_map_process_always
	.globl	_map_process
	.globl	_map_kernel
	.globl	_map_restore
	.globl	_map_save

_map_process_always:
_map_process:
_map_kernel:
_map_restore:
_map_save:
	ret

/*
 *	BIOS disk I/O wrapper
 *	int hd_biosio(uint16_t dev_op, uint16_t count, uint16_t sector, void *buf)
 *	  dev_op at rr14(#4): device in high byte, opcode in low byte
 *	  count at rr14(#6): sector count
 *	  sector at rr14(#8): starting sector number
 *	  buf at rr14(#10): buffer address (32-bit segmented pointer)
 *
 *	Returns 0 on success, error code on failure (in r2).
 *	Must save/restore R10 (udata pointer) since BIOS uses rr10 for buffer.
 */
	.globl	_hd_biosio
_hd_biosio:
	pushl	@rr14, rr10		! save udata pointer
	pushl	@rr14, rr8		! save callee-saved

	di	vi,nvi			! disable interrupts during BIOS call

	ld	r7, rr14(#12)		! dev_op (adjusted for 2 pushes = +8)
	ld	r8, rr14(#14)		! count
	ld	r9, rr14(#16)		! sector
	ldl	rr10, rr14(#18)		! buffer (seg:off) — clobbers R10!

	ldl	rr12, #0x84000068	! BIOS disk_io entry point
	call	@rr12

	ldb	rl2, rl7		! return error code in r2
	subb	rh2, rh2		! zero extend

	ei	vi,nvi			! re-enable interrupts

	popl	rr8, @rr14		! restore callee-saved
	popl	rr10, @rr14		! restore udata pointer
	ret

/*
 *	Debug character output via serial port (i8251A at 0x00C1)
 *	Called from C: void outchar(uint_fast8_t c)
 *	Argument on stack (stack calling convention)
 */
_outchar:
	pushl	@rr14, rr8
	pushl	@rr14, rr10
	pushl	@rr14, rr12
	ldb	rl0, rr14(#17)		! load char arg (3 pushes*4 + retaddr 4 + 1)

	! Serial output
_outchar_wait:
	inb	rl1, #TTY_CTRL		! read status
	bitb	rl1, #2			! TxEMPTY? (not gated by CTS)
	jr	z, _outchar_wait
	outb	#TTY_DATA, rl0

	! CRT output (BIOS clobbers r0-r13, already saved above)
	ldl	rr12, #0x84000080	! BIOS put_char entry point
	call	@rr12

	popl	rr12, @rr14
	popl	rr10, @rr14
	popl	rr8, @rr14
	ret

/*
 *	CRT character output via BIOS PROM put_char
 *	void crt_put(uint_fast8_t c)
 *
 *	BIOS entry 0x84000080: character in rl0
 *	BIOS clobbers r0-r7 and potentially r8-r13, so we must
 *	save all callee-saved registers.
 */
_crt_put:
	pushl	@rr14, rr8
	pushl	@rr14, rr10
	pushl	@rr14, rr12

	ldb	rl0, rr14(#17)		! char arg (offset: 3 pushes * 4 + 4 + 1)

	di	vi,nvi			! prevent re-entry from timer echo
	ldl	rr12, #0x84000080	! BIOS put_char entry point
	call	@rr12
	ei	vi,nvi

	popl	rr12, @rr14
	popl	rr10, @rr14
	popl	rr8, @rr14
	ret

