        .export init

; Linked and will end up at 0x300

	.common
	jp init

	.code
init:
        di
        ; switch to stack in high memory
        ld sp, kstack_top

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
