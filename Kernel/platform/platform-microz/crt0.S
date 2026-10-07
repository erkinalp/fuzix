;
;	We start from cold as we are the ROM itself
;

	.abs
	.org	0
start:
	jp	setup
	.ds	5
rst8:	ret
	.ds	7
rst10:	ret
	.ds	7
rst18:	ret
	.ds	7
rst20:	ret
	.ds	7
rst28:	ret
	.ds	7
rst30:	ret
	.ds	7
rst38:
	jp	interrupt_handler
	; TODO handle as an error

serini:
	.byte	0x18	; Reset
	.byte	0x14
	.byte	0x44	; Set 8N1
	.byte	0x03
	.byte	0xC1
	.byte	0x05
	.byte	0xEA
	.byte	0x11	; interrupts off
	.byte	0x00

	.org	0x66
nmi:	jp	nmi_handler

setup:
	di
	ld	a,2		; CSBR
	out	(0xEE),a
	ld	a,0x0C		; ROM low 12K RAM D000-FFFF high RAM
	out	(0xEF),a
	ld	a,3
	out	(0xEE),a	; MISC
	out	(0xEF),a	; CS0 and CS1 enabled

	; 	RAM is now active in the upper quadrant

	ld	c,0x19
	ld	b,9
	ld	hl,serini
	otir
	inc	c
	inc	c
	ld	hl,serini
	otir

	; 	Serial is now functional but polled

	;	We need to copy between ROM and RAM for the upper quadrant

	ld	a,2		; Select CSBR
	out	(0xEE),a
	ld	c,0xEF		; Data port
	ld	de,0x0C0F
	ld	hl,0xD000
copy_over:
	out	(c),e		; ROM in
	ld	b,(hl)
	out	(c),d		; ROM out
	ld	(hl),b
	inc	hl		; Next
	bit	7,h
	jr	nz,copy_over	; Done FFFF ?

	;	Our kernel memory map is now completed
	;	We have
	;	0000-CFFF	Kernel ROM
	;	D000-FFFF	Kernel RAM (high RAM)
	;	We need to figure how the best use of the other 0D000 block
	;	(the other 0000-0FFF is inaccessible)

	di
	ld sp, kstack_top

	; zero the BSS and buffers
	ld hl, __bss
	ld de, __bss + 1
	ld bc, __bss_size - 1
	ld (hl), 0
	ldir
;	Zero buffers area
	ld hl, __buffers
	ld de, __buffers + 1
	ld bc, __buffers_size - 1
	ld (hl), 0
	ldir
	call init_hardware
	call _fuzix_main
	di
stop:	halt
	jr stop

