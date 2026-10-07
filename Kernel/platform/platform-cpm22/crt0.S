;
;	We are loaded by whatever loader was written for the platform. We
;	are started in bank 0. We might have been loaded by a loader or by
;	CP/M 2.x
;
	.code

start:
	jr	go
	.word	0x1DEA		; magic for config check
	.word	__bss - 0x100	; pointer to where to stuff sysmod
go:
        di
        ld	sp, kstack_top


        ; Configure memory map
        call	init_early

	; move the common memory where it belongs
	; as we need this to boot further
	; this wipes the stack we are using but that is ok

	ld	hl, __bss
	ld	de, _sysmod
	ld	bc, 0x400		; 1K sysmod area
	ldir
	ld	de, __common
	ld	bc, __common_size
	ldir
	; and the discard
	ld	de, __discard
	ld	bc, __discard_size
	ldir

	; then zero the data area
	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl), #0
	ldir

        ; Hardware setup
        call init_hardware
        ; Call the C main routine
        call _fuzix_main
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr stop
