	; We are entered at 0x0100 in the first RAM bank with the low 32K
	; sanely mapped but quite possibly not the rest, and with interrupts
	; off.
	;
	.code
init:
        ld	sp, kstack_top

	exx

        ; move the common memory where it belongs    
        ld	hl, __bss
        ld	de, __common
        ld	bc, __common_size
        ldir
        ; and the discard
        ld	de, __discard
        ld	bc, __discard_size - 1
	add	hl,bc
	ex	de,hl
	add	hl,bc
	ex	de,hl
	inc	bc
        lddr

        ; then zero the data area
        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Configure memory map
        call	init_early

	; We now have the ROM info to hand and have cleared stuff so it
	; is safe to write these into memory

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop
