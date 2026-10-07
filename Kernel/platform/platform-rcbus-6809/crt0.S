#include "kernel.def"

		.code

		; On entry 0000-BFFF are in situ. Cxxx holds the common for
		; Fxxx

		.word 0x6809
start:
		orcc #0x10		; interrupts definitely off
		lds #kstack_top		; note we'll wipe the stack later

		ldx #$E000
		ldy #$F000
copy1:
		ldd ,x++
		std ,y++
		cmpy #0000
		beq move_done
		; Don't copy into the I/O window
		cmpy #$FE00
		bne copy1
		leax $100,x
		leay $100,y
		bra copy1
move_done:	jmp premain

		.discard

premain:
		clra
		ldx #_udata
udata_wipe:	sta ,x+
		cmpx #_udata+U_DATA__TOTALSIZE
		blo udata_wipe
		ldx #__bss
		ldy #__bss_size
bss_wipe:	sta ,x+
		leay -1,y
		bne bss_wipe
		jsr init_early
		jsr init_hardware
		jmp main

		.code

main:		lda #>_udata
		tfr a,dp		; We use DP for the udata
		jsr _fuzix_main
		orcc #0x10		; we should never get here
stop:		bra stop
