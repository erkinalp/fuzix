		.code

;
;	Once the loader completes it jumps here
;	A holds the type of mapper the boot block was for
;
;	0: Supermem
;	1: Selector
;
	.export stub
	.export stub_end
	.export start

	.data
	jp	start
	.code
start:
	; Take care to preserve A until init_early
	ld sp, #kstack_top	; just below us
	; then zero the data area
	ld hl, #__bss
	ld de, #__bss + 1
	ld bc, #__bss_size - 1
	ld (hl), #0
	ldir
	; We pass A into init_early holding the mapper type
	call init_early
	push af
	call init_hardware
	pop af
	push af
	call _vtinit
	pop af
	push af
	call _fuzix_main
	pop af
	di
stop:	halt
	jr stop
	.common
stub:
	.ds 700
stub_end:
