	; exported
	.export start

#include "kernel.def"

	; startup code
	.code

	; this will sit at address 0 and be overwritten with the
	; jump-through-null trap later.
	jmp start

	.discard

start:
	; we enter from bootloader in task 1 (kernel)
	lds #kstack_top	; note we'll wipe the stack later

	orcc #0x10		; interrupts definitely off

	; copy COMMON area from page 3 to page 31, using area 0
	ldd #0x031f
	ldx #0x0000
	stb 0xff34		; tast 1 area 0 = page 31
	; clear tty1 RG6 VRAM
	ldu #$ffff
cp1:	stu ,x++
	cmpx #$1800
	blo cp1
	; clear tty2 SG4 VRAM
	ldu #$2020
cp2:	stu ,x++
	cmpx #$3000
	blo cp2
	; copy COMMON from page 3
cp3:	sta 0xff34		; task 1 area 0 = page 3
	ldu ,x
	stb 0xff34		; task 1 area 0 = page 31
	stu ,x++
	cmpx #0x4000
	blo cp3
	clr 0xff34		; task 1 area 0 = page 0

	; ensure COMMON is on for top 4K
	lda #$01
	sta 0xff3f

	jsr map_kernel

	; zero udata
	clra
	ldx #_udata
udata_wipe:
	sta ,x+
	cmpx #_udata+U_DATA__TOTALSIZE
	blo udata_wipe
	; zero kernel bss
	ldx #__bss
	ldy #__bss_size
bss_wipe:
	sta ,x+
	leay -1,y
	bne bss_wipe

	jsr init_early
	jsr init_hardware
	jmp main

	.code

main:	lda #>_udata
	tfr a,dp		; We use DP for the udata
	jsr _fuzix_main
	orcc #0x10		; we should never get here
stop:	bra stop
