# 1 "crt0.S"
	        ; startup code @0
	        .code

; This area will be covered by the boot block in the boot image and then
; copid into the runtime one. We reuse the low 0x80 for vectors
		.ds	0x223
;
; Execution begins with us correctly mapped and at 0x0223
;
;
;
;	Our copy of the image is entered here with the system mapped at
; banks 3,4,5,6 (0-2 hold the bootblock and image for rebooting)
;
start:		di
		ld sp, kstack_top
		; move the common memory where it belongs    
		ld hl, __bss
		ld de, __common
		ld bc, __common_size
		ldir
		; TODO; check commondata
		; and the discard
		ld de, __discard
		ld bc, __discard_size
		ldir
		; then zero the data area
		ld hl, __bss
		ld de, __bss + 1
		ld bc, __bss_size - 1
		ld (hl), 0
		ldir

		call init_early
		call init_hardware
		call _fuzix_main
		di
stop:		halt
		jr stop
