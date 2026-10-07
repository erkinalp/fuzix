/*
 *	Z8001 (segmented) C runtime startup — no stdio init variant
 *
 *	Binary layout:
 *	  text[0x00..0x1F] = VDSO placeholder (overwritten by kernel)
 *	  text[0x20+]      = actual code (entry point)
 *
 *	The exec loader places on the user stack (all via uputl, 4 bytes each):
 *	  ISP+0: argc (4 bytes, uint32_t)
 *	  ISP+4: argv (4 bytes, segmented pointer)
 *	  ISP+8: envp area
 */
	.segm
	.globl	__start
	.globl	___main
	.globl	_main
	.globl	_exit
	.globl	___argv
	.globl	_environ

	.data

_environ:
	.long	0

	.text

	/* Reserve 0x20 bytes for VDSO (installed by kernel at codebase+0) */
	.space	0x20

/* Entry point at text[0x20] */
__start:
	/* Save environ pointer — envp[] array starts at ISP+8 */
	ldl	rr2, rr14
	addl	rr2, #8
	ldl	_environ, rr2

	/* Save argv for getopt etc */
	ldl	rr2, rr14(#4)
	ldl	___argv, rr2

	/* Push argc/argv for main(int argc, char *argv[]) */
	ldl	rr4, rr14(#4)		! argv (32-bit)
	ld	r2, rr14(#2)		! argc (low 16 bits of 32-bit value)
	pushl	@rr14, rr4		! push argv
	push	@rr14, r2		! push argc

	/* Call main */
	call	_main
	addl	rr14, #6		! clean pushed args

	/* Exit with return value from main */
	push	@rr14, r2
	call	_exit

/* GCC constructor stub */
___main:
	ret
