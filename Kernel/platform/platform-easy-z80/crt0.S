#include "kernelu.def"

        ; startup code
	.code
init:
	di

	; setup the memory paging for kernel
        ld a, 33
        out (MPGSEL_1), a       ; map page 33 at 0x4000
        inc a
        out (MPGSEL_2), a       ; map page 34 at 0x8000
	inc a
        out (MPGSEL_3), a       ; map page 35 at 0xC000

mappedok:
        ; switch to stack in high memory
        ld sp, kstack_top

        ; Zero the data area
        ld hl, __bss
        ld de, __bss + 1
        ld bc, __bss_size - 1
        ld (hl), 0
        ldir

        ; Hardware setup
        call init_hardware

        ; Call the C main routine
        call _fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr stop
