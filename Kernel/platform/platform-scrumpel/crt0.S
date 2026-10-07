	;
	;	For the Scrumpel this code assumes the kernel is at 0x00000
	;	on entry. Common and other high stuff is packed on the end
	;	of the image so if needed crt0 can adjust the other bank
	;	registers.
	;


	; 2013-12-18 William R Sowerbutts

	.z180

#include "kernelu.def"
#include "../../cpu-z180/z180.def"

        ; startup code
	.code

init:
        di
        ld	sp, kstack_top

	xor	a
	out0	(MMU_BBR),a
	out0	(MMU_CBR),a

	; For now we are loading the IHX file directly so don't
	; want to unpack stuff, but do need to sort out the initializer
	; instead

;	ld hl,#s__INITIALIZER
;	ld de,#s__INITIALIZED
;	ld bc,#l__INITIALIZER
;	ldir

;	jr skip_unpack


        ; move the common memory where it belongs    
        ld	hl, __bss
        ld	de, __common
        ld	bc, __common_size
        ldir
        ; and the discard
        ld	de, __discard
        ld	bc, __discard_size
        ldir

skip_unpack:
        ; then zero the data area
        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Configure memory map
        call	init_early

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop
