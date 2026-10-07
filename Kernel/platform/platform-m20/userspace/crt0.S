! Z8001 FUZIX user-space crt0
!
! Binary layout must match 68000 convention:
!   text[0x00..0x1F] = VDSO placeholder (overwritten by kernel)
!   text[0x20+]      = actual code (entry point)
!
! The exec loader reads a_text - 0x20 bytes from the file and
! writes them to codebase + 0x20. The VDSO at codebase + 0x00
! is written by install_vdso.
!
! Relocation offsets are from text[0] (including VDSO area),
! so they naturally add up correctly with codebase + v.

	.segm
	.text
	.global	_start
	.global	___main

! VDSO placeholder — kernel overwrites first 16 bytes
	.space	32		! 0x20 bytes: 16 VDSO + 16 padding

! Entry point at text[0x20]
_start:
	! Stack set up by kernel. argc/argv/envp on stack.
	ld	r2, @rr14		! argc
	ldl	rr4, rr14(#2)		! argv
	pushl	@rr14, rr4		! push argv
	push	@rr14, r2		! push argc
	call	_main
	addl	rr14, #6		! clean stack

	! main returned — _exit(retval)
	ld	r3, r2
	ld	r1, #0			! _exit
	sc	#0
	halt

! GCC constructor stub
___main:
	ret
