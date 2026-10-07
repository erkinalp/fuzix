;
;	Low level support code. This will become the system customisation
;	block in the end.
;
		.export outchar
		.export _plt_monitor
		.export _plt_reboot

		.export init_early
		.export init_hardware

		.export map_kernel
		.export map_kernel_di
		.export map_kernel_restore
		.export map_proc
		.export map_proc_a
		.export map_proc_always
		.export map_proc_always_di
		.export map_save_kernel
		.export map_restore

		.export _c_sysm_conconf
		.export _c_sysm_auxconf

		.export _program_vectors
		.export plt_interrupt_all

		.export _int_disabled

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can grow to fit the space free)
;
		.buffers
		.export _bufpool
_bufpool:
		.ds BUFSIZE * NBUFS
		.code

init_early:
		im 1
		ld a,0x08
		out (20),a
		ret

		.common
;
;	Wrap conout for our console output
;
outchar:
		push af
		push bc
		push de
		push hl
		ld c,a
		call _cpm_conout
		pop hl
		pop de
		pop bc
		pop af
		ret

_plt_monitor:
		jp _sysmod_monitor
_plt_reboot:
		jp _sysmod_reboot

init_hardware:
		; Set up the BIOS calling interface
		ld a,(2)
		ld (biosbase + 1),a
		call _sysmod_init
		; Set up the system
		call program_vectors_k
		ld a,1
		out (27),a
		jp _init_hardware_c

map_proc_a:
		ld (map),a
		jp _sysmod_set_map

map_proc:
		ld a,h
		or l
		jr z, map_kernel
		ld a,(hl)
		jp _sysmod_set_map

map_proc_always:
map_proc_always_di:
		push af
		ld a,(_udata + U_DATA__U_PAGE);
		call map_proc_a
		pop af
		ret
map_kernel:
map_kernel_di:
map_kernel_restore:
		push af
		xor a
		call map_proc_a
		pop af
plt_interrupt_all:
		ret

map_save_kernel:
		push af
		ld a,(map)
		ld (saved_map),a
		xor a
		call _sysmod_set_map
		pop af
		ret

map_restore:
		push af
		ld a,(saved_map)
		ld (map), a
		call _sysmod_set_map
		pop af
		ret

_program_vectors:
		; we are called, with interrupts disabled, by both newproc() and crt0
		; will exit with interrupts off
		di ; just to be sure
		pop de ; temporarily store return address
		pop hl ; function argument -- base page number
		push hl ; put stack back as it was
		push de

		call map_proc

program_vectors_k:
		; now install the interrupt vector
		ld hl, interrupt_handler
		call _sysmod_irq_handler

		ld a,0xC3		; JP
		; Set vector for jump to NULL
		ld (0x0000), a   
		ld hl, null_handler  ;   to Our Trap Handler
		ld (0x0001), hl

		ld hl, nmi_handler
		call _sysmod_nmi_handler

		jp map_kernel

;
;	C compiler glue for sysmod with arguments
;
_c_sysm_conconf:
		pop de
		pop hl
		push hl
		push de
		jp _sysmod_conconf
_c_sysm_auxconf:
		pop de
		pop hl
		push hl
		push de
		jp _sysmod_auxconf

		.commondata

_int_disabled:
		.byte 1
map:
		.byte 0
saved_map:
		.byte 0


