#include "kernelu.def"


	.code

; Starts at 0x0100
; We are mapped with bank 1 page 1 low and bank 1 page 2 high (fixed)
; Or on a non MDISK system with the 64K RAM low/high
;
; We were loaded as a packed image from 0000 up. The loader
; in FE00-FFFF gets replaced with the serial buffers once we take
; control if the loader is used.
;
; This works as a raw disk load or a CP/M app
;
        di

	ld	sp,kstack_top

	; Discard is packed over the BSS to keep the image smaller
	; for loading
	ld	hl, __bss
        ld	de, __discard
        ld	bc, __discard_size
        ldir

        ; Zero the data area
        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop

	.discard
	.export im2_vectors
;
;	Make sure common memory starts with the im2 vectors
;
im2_vectors:
	; First 16 vectors
	.word	0
	.word	0
	.word	0
	.word	interrupt_handler	; CTC 3 vector
	.word	0
	.word	0
	.word	0
	.word	0
	.word	siob_txd
	.word	siob_status
	.word	siob_rx_ring
	.word	siob_special
	.word	sioa_txd
	.word	sioa_status
	.word	sioa_rx_ring
	.word	sioa_special
