;
;    TC2068 hardware support
;

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
        .export plt_interrupt_all
	.export _plt_idle

        .export map_kernel
        .export map_proc_always
        .export map_proc
        .export map_kernel_di
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_kernel_restore
	.export map_for_swap
	.export map_video
	.export map_buffers
	.export current_map

        .export _need_resched
	.export _int_disabled
	.export _vtborder

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
        rst	0		; back into our booter

plt_interrupt_all:
        ret

	.code

_plt_idle:
	halt
	ret

	.commondata

_int_disabled:
	.byte	1

_vtborder:		; needs to be common
	.byte	0


; -----------------------------------------------------------------------------
; KERNEL CODE BANK (above 0x4000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.code

init_early:
	ld	a, 0xFF
	ld	(current_map),a
	out	(0xF4),a		; Map kernel fully
        ret

	.code
init_hardware:
        ; set system RAM size
        ld	hl, 80
        ld	(_ramsize), hl
        ld	hl, 33	      ; 32K for kernel/screen/etc
        ld	(_procmem), hl

	ld	a, 0x3E
	out	(0xFF),a
        ; screen initialization
	call	_vtinit

        ret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_program_vectors:
	ret

	; Swap helper. Map the page in A into the address space such
	; that swap_map() gave the correct pointer to use. Undone by
	; a map_kernel_{restore}
map_proc:
        ld	a, h
        or	l
        jr	z, map_kernel
map_for_swap:
map_proc_always:
map_proc_always_di:
	push	af
	ld	a, 0x03			; catridge in low 16K only
	ld	(current_map), a
	out	(0xF4), a
	pop	af
	ret
;
;	Save and switch to kernel
;
map_save_kernel:
	push	af
        ld	a, (current_map)
        ld	(map_store), a
	pop	af
map_buffers:
map_kernel_di:
map_kernel:
map_kernel_restore:
	push	af
	ld	a,0xFF			; entirely from cartridge
	ld	(current_map),a
	out	(0xF4),a
	pop	af
	ret

map_video:
	push	af
	ld	a,0xF3			; entirely from cartridge except video
	ld	(current_map),a
	out	(0xF4),a
	pop	af
	ret

map_restore:
	push	af
        ld	a, (map_store)
	ld	(current_map),a
	out	(0xF4),a
	pop	af
	ret

;
;	We have no easy serial debug output instead just breakpoint this
;	address when debugging.
;
outchar:
	ld	(_tmpout), a
	push	de
	push	hl
	ld	hl, 1
	push	hl
	ld	hl, _tmpout
	push	hl
	call	_vtoutput
	pop	af
	pop	af
	pop	hl
	pop	de
        ret

	.commondata

_tmpout:
	.byte	1

current_map:		; place to store current page number. Is needed
        .byte	0	; because we have no ability to read 0xF4 port
			; to detect what page is mapped currently 
map_store:
        .byte	0

_need_resched:
        .byte	0
