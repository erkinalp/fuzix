		.abs
		.org 0
		; Start up on 3vZ80
		; Fix up the banks. Right now bank 1 holds the common but
		; we need it in 0x1F
		ld hl,bootstrap
		ld de,0xFF00
		ld bc,0x0100
		ldir
		ld sp,0xFFFF
		call 0xFF00
		; And this will eat 0000-00FF
		ld a,1
		jp bootup
bootstrap:	; must be relocatable
		ld a,0x01
		out (0x1F),a		; get our upper bank
		ld hl,0x0000
		ld de,0x8000
		ld bc,0x7F00
		ldir			; up it goes
		xor a
		out (0x1F),a		; correct bank low
		ret

	        ; startup code
	        .code

		; Load at 0x0100
start:
		jp go
		.word 0x10DE
go:
		xor a
bootup:
		di
		ld sp, kstack_top
		ld hl, __bss
		ld de, __common
		ld bc, __common_size
		ldir
		ld de, __commondata
		ld bc, __commondata_size
		ldir
		ld de, __discard
		ld bc, __discard_size - 1
		ex de,hl
		add hl,bc
		ex de,hl
		add hl,bc
		lddr
		ldd

		; Zero the data area
		ld hl, __bss
		ld de, __bss + 1
		ld bc, __bss_size - 1
		ld (hl), 0
		ldir

		; Zero buffers area
		ld hl, __buffers
		ld de, __buffers+1
		ld bc, __buffers_size - 1
		ld (hl), 0
		ldir

		; None of the setup touches A
		ld (_machtype),a

		call init_early
		call init_hardware
		call _fuzix_main
		di
stop:		halt
		jr stop
