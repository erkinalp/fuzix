;
;    ZX Uno hardware support
;

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
        .export plt_interrupt_all
	.export _plt_idle

        .export map_kernel
        .export map_proc_always
        .export map_kernel_di
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_proc_save
	.export map_kernel_restore
	.export map_for_swap
	.export map_proc_a
	.export map_video_save

	.export _int_disabled
	.export _portff

        ; exported debugging tools
        .export _plt_monitor
	.export _plt_reboot
        .export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (below 0x4000)
; -----------------------------------------------------------------------------
	.common

_plt_monitor:
	;
	;	Not so much a monitor as wait for space
	;
	ld	a, 0x7F
	in	a, (0xFE)
	rra
	jr	c, _plt_monitor

_plt_reboot:
	di
	im	1
	ld	bc, 0x7FFD
	xor	a	; 128K ROM, initial banks, low screen
	; FIXME: will need to put the out(c), a at 0xFFFE and
	; jump to it
	out	(c), a
        rst	0	; Into the ROM

plt_interrupt_all:
        ret

	.code

_plt_idle:
	halt
	ret

	.commondata
_int_disabled:
	.byte	1


; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (above 0x4000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.code
;
;	The memory banker will deal with the map setting
;
init_early:
        ret

	.common

init_hardware:
        ; set system RAM size
	; sort of anyway - we need to revisit this with the real values
	; once we have the rest of the map worked out
        ld	hl, 192
        ld	(_ramsize), hl
        ld	hl, 96		; 64K for kernel 16K for screen and lose some
				; to common
        ld	(_procmem), hl

        ; screen initialization
	ld	a, (_portff)
	out	(0xff), a

	jp	_vtinit

	.common

_program_vectors:
	ret

;
;	On the ZX Uno this is simple. On the SE/Chloe however the
;	dual MMU has restrictions. In particular for us the top page
;	must be even when using dock/ex space.
;
map_for_swap:
map_proc_a:
	push	af
	push	bc
map_user:
	di
	ld	(user_map), a
	ld	bc, 0x7FFD
	ld	a, 0x08
	out	(c), a		; Bank 0 high
	ld	a, 0xFC
	out	(0xF4), a	; DOCK/EXT on
	ld	bc, (user_map)	; user_map into C
	dec 	c		; now 0x00 or 0x80
	ld	a, (_portff)
	and	0x7F
	or	c		; DOCK/EXT bit
	ld	(_portff), a
	out	(0xFF), a	; and set up the choice
ei_out:
	ld	a, (_int_disabled)
	or	a
	jr	nz, no_ei
	ei
no_ei:
	pop	bc
	pop	af
	ret

map_proc_save:
map_proc_always:
map_proc_always_di:
	push	af
	push	bc
	ld	a, (_udata+U_DATA__U_PAGE)
	jp	map_user

map_proc_hl:
	push	af
	push	bc
	ld	a, (hl)
	jp	map_user

;
;	Kernel - clear the bank register so we get standard memory
;	(plus the DIVMMC space)
;
map_kernel_di:
map_kernel:
map_kernel_restore:
	push	af
	push	bc
	di
	xor	a
	ld	(user_map), a
	out	(0xF4), a	; Dock/Ext off
	ld	a, 0x0B		; bank 3 screen 7
	ld	bc, 0x7FFD
	ld	(high_map), a
	out	(c), a
	jp	ei_out
;
;	Temporarily switch to video memory, this lives in bank 7 so replaces
;	some of the kernel. This is fine as we are in common
;
map_video_save:
	push	af
	push	bc
	di
	ld	a, 0x0F		; bank 7 screen 7
	ld	bc, 0x7FFD
	ld	(high_map), a
	out	(c), a
	jp	ei_out
;
;	Save and switch to kernel (always in IRQ context)
;
map_save_kernel:
	push	af
	push	bc
	ld	a, (user_map)
	ld	(user_store), a
        ld	a, (high_map)
        ld	(high_store), a
	xor	a
	ld	(user_map), a
	out	(0xF4), a
	ld	bc, 0x7FFD
	ld	a, 0x0B
	ld	(high_map), a
	out	(c), a
	pop	bc
	pop	af
	ret

map_restore:
	push	af
	push	bc
	ld	a, (user_store)
	ld	(user_map), a
	or	a
	jp	nz, map_user
	out	(0xF4), a
	ld	a, (high_store)
	ld	(high_map), a
	ld	bc, 0x7FFD
	out	(c), a
	pop	bc
	pop	af
	ret

;
;	We have no easy serial debug output instead just breakpoint this
;	address when debugging.
;
outchar:
	ld (_tmpout), a
	push	bc
	push	de
	push	hl
	push	ix
	ld	hl, 1
	push	hl
	ld	hl, _tmpout
	push	hl
	call	_vtoutput
	pop	af
	pop	af
	pop	ix
	pop	hl
	pop	de
	pop	bc
        ret

	.commondata

_tmpout:
	.byte	1

user_map:
	.byte	0
user_store:
	.byte	0
high_map:
	.byte	0
high_store:
	.byte	0

_portff:
	.byte	0x3E	    ; High resolution white on black
