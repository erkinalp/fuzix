		; exported
		.export start

	        ; startup code
	        .code

;
;	Entry - cartridge mapped at C000, system ROM at 8000, RAM at low 32K
;
start:
		orcc #0x10		; interrupts definitely off
		lds #$0100		; not written by loader
		clr $ffde		; make sure ROM is mapped
		clr $ffd4		; low 32K in low 32K
		jsr load_image		; load the rest of the OS from disk
		jmp main

		.code
main:		
		lds #kstack_top
		ldx #__bss
		ldy #__bss_size
		clra
bss_wipe:	sta ,x+
		leay -1,y
		bne bss_wipe
		; This might be in BSS so don't save until we've wiped!
		lda #0
		ldb $80FD		; save from ROM space
		cmpb #0x49		; Dragon32
		beq identified
		inca
		cmpb #0x31		; COCO1/2
		beq identified
		inca
		cmpb #0x32		; COCO3
		beq identified
		inca			; Beats me
identified:
		sta _system_id		; what sort of a box are we ?
		jsr init_early
		jsr init_hardware
		jsr _fuzix_main
		orcc #0x10
stop:		bra stop

; FIXME: where to abs this
		.data
		.byte 0x15,0xC0,0xDE,0x4C,0x0C,0x02

