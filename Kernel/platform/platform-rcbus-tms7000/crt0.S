#include "../../cpu-tms7000/kernel-tms7000.def"

	.common
	; Starts at 0x500

init:
        dint
	mov	%CPUSTK,b
	ldsp
	movd	%kstack_top,r15

        call	@init_early

	; Wipe the BSS
	movd	%__bss,r13
	movd	%__bss_size,r11
	decd	r11
	jnc	nobss
	add	r10,r12
	adc	r11,r13
	clr	a
wipe:
	sta	*r13
	decd	r13
	decd	r11
	jc	wipe
	
nobss:
        call	@init_hardware

        call	@_fuzix_main
        dint
end:    idle
        jmp end


	.abs
	.org	0xFFD0
	.word	__lstref0		; trap 23
	.word	__push0			; trap 22
	.word	__pargr1		; trap 21
	.word	__nstore_2		; trap 20
	.word	__cceqconst0		; trap 19
	.word	__garg10r2		; trap 18
	.word	__popw			; trap 17
	.word	__cceqconstb		; trap 16
	.word	__gargr4		; trap 15
	.word	__load2			; trap 14
	.word	__nref_1		; trap 13
	.word	__plusplus		; trap 12
	.word	__pushacl		; trap 11
	.word	__frame			; trap 10
	.word	__gargr1		; trap 9
	.word	__pushln		; trap 8
	.word	__pargr2		; trap 7
	.word	__nref_2		; trap 6
	.word	__gargr2		; trap 5
	.word	__pushac		; trap 4
	.word	0			; INT 3
	.word	0			; INT 2
	.word	0			; INT 1
	.word	0			; RESET
