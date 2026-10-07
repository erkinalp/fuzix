! Z8001 FUZIX syscall wrappers
!
! Kernel SC convention (with 32-bit arg_t):
!   R1       = syscall number (low byte)
!   RR2      = argn (32-bit: R2=high, R3=low)
!   RR4      = argn1 (32-bit: R4=high, R5=low)
!   RR6      = argn2 (32-bit: R6=high, R7=low)
!   Return in RR2 (R2:R3)
!
! C calling convention (stack-based, no -mregparms):
!   Args on stack at rr14(#4), rr14(#6/8), etc.
!   Return in r2 (16-bit) or rr2 (32-bit)
!
! On big-endian Z8001, a 32-bit return value N is r2=0, r3=N.
! C functions returning int (16-bit) expect the result in r2.
! Add 'ld r2, r3' after sc for int-returning syscalls.
! Do NOT add it for pointer-returning syscalls (signal).
!
! Syscall numbers from Kernel/include/syscall_name.h:
!   0 = _exit, 1 = open, 2 = close, 7 = read, 8 = write

	.segm
	.text

! void _exit(int status)
	.global	__exit
__exit:
	ld	r1, #0			! syscall 0 = _exit
	clr	r2
	ld	r3, rr14(#4)		! status (16-bit → rr2 = 0:status)
	sc	#0
	halt

! int open(const char *path, int flags)
	.global	_open
_open:
	ld	r1, #1			! syscall 1 = open
	ldl	rr2, rr14(#4)		! path (32-bit segmented ptr → rr2)
	clr	r4
	ld	r5, rr14(#8)		! flags (16-bit → rr4 = 0:flags)
	clr	r6
	clr	r7			! mode = 0
	sc	#0
	ld	r2, r3
	ret

! int read(int fd, void *buf, int count)
	.global	_read
_read:
	ld	r1, #7			! syscall 7 = read
	clr	r2
	ld	r3, rr14(#4)		! fd
	ldl	rr4, rr14(#6)		! buf
	clr	r6
	ld	r7, rr14(#10)		! count
	sc	#0
	ld	r2, r3
	ret

! int fork(void) — kernel _fork(uint16_t flags, void *addr)
! Save callee-saved regs on user stack: the child gets a copy
! of the user stack and pops them on return from fork.
	.global	_fork
_fork:
	pushl	@rr14, rr8
	pushl	@rr14, rr12
	ld	r1, #32			! syscall 32 = _fork
	clr	r2
	clr	r3			! flags = 0
	clr	r4
	clr	r5			! addr = NULL
	sc	#0
	popl	rr12, @rr14
	popl	rr8, @rr14
	ld	r2, r3
	ret

! int getpid(void)
	.global	_getpid
_getpid:
	ld	r1, #18			! syscall 18 = getpid
	sc	#0
	ld	r2, r3
	ret

! void *signal(int sig, void *handler) — returns 32-bit pointer
	.global	_signal
_signal:
	ld	r1, #35			! syscall 35 = signal
	clr	r2
	ld	r3, rr14(#4)		! sig (16-bit)
	ldl	rr4, rr14(#6)		! handler (32-bit pointer)
	sc	#0
	ret				! return full rr2 (32-bit pointer)

! int kill(int pid, int sig)
	.global	_kill
_kill:
	ld	r1, #39			! syscall 39 = kill
	clr	r2
	ld	r3, rr14(#4)		! pid
	clr	r4
	ld	r5, rr14(#6)		! sig
	sc	#0
	ld	r2, r3
	ret

! int execve(const char *path, char *argv[], char *envp[])
	.global	_execve
_execve:
	ld	r1, #23			! syscall 23 = execve
	ldl	rr2, rr14(#4)		! path (32-bit ptr)
	ldl	rr4, rr14(#8)		! argv (32-bit ptr)
	ldl	rr6, rr14(#12)		! envp (32-bit ptr)
	sc	#0
	ld	r2, r3
	ret

! int waitpid(int pid, int *status, int options)
	.global	_waitpid
_waitpid:
	ld	r1, #55			! syscall 55 = waitpid
	clr	r2
	ld	r3, rr14(#4)		! pid
	ldl	rr4, rr14(#6)		! status ptr (32-bit)
	clr	r6
	ld	r7, rr14(#10)		! options
	sc	#0
	ld	r2, r3
	ret

! int write(int fd, const void *buf, int count)
	.global	_write
_write:
	ld	r1, #8			! syscall 8 = write
	clr	r2
	ld	r3, rr14(#4)		! fd (16-bit → rr2 = 0:fd)
	ldl	rr4, rr14(#6)		! buf (32-bit segmented ptr → rr4)
	clr	r6
	ld	r7, rr14(#10)		! count (16-bit → rr6 = 0:count)
	sc	#0
	ld	r2, r3
	ret
