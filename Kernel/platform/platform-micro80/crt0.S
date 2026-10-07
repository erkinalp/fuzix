;
;	We are loaded from CP/M at the moment
;
#include "kernelu.def"

;
;	We don't want our image packed
;
		.code
;
;	Runs from 0x0100
;
		di

		ld sp, kstack_top
		; Zero the data area
		ld hl, __bss
		ld de, __bss + 1
		ld bc, __bss_size - 1
		ld (hl), 0
		ldir
		; Zero buffers area
		ld hl, __buffers
		ld de, __buffers + 1
		ld bc, __buffers_size - 1
		ld (hl), 0
		ldir

        	; Hardware setup
	        call init_hardware

	        ; Call the C main routine
	        call _fuzix_main
	        ; fuzix_main() shouldn't return, but if it does...
	        di
stop:		halt
		jr stop

