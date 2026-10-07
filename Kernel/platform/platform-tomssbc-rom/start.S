;	This chunk is placed into 0x0000-0x003F of all banks
;

		.abs

rst0:		jp next	;	Has to be JP to avoid triggering debug checks
next:		di
		; ROM is on and we are in bank 0
		ld a,0x01
		out (0x3E),a
		out (0x3F),a
		; now continuing in the copy in bank 3 which holds
		; the literals, data and common space
		ld hl,0x040
		ld de,0x8000
		ld bc,0x1000
		ldir
		ld de,0xC000
		ld bc,0x2FC0
		ldir
		ld sp,0xFFFF
		jp _go

		.org 0x38

rst38:		jp interrupt_handler

