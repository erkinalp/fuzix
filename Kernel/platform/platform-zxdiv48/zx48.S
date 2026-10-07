;
;    ZX Spectrum 48K with DivIDE plus hardware support
;

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
        .export plt_interrupt_all
	.export _plt_idle

        .export map_kernel
	.export map_for_swap
        .export map_proc_always
        .export map_proc
        .export map_kernel_di
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_proc_save
	.export map_kernel_restore
	.export map_buffers
	.export map_bank_a
	.export map_save_kmap
	.export map_restore_kmap
	.export current_map
	.export switch_bank

        .export _need_resched
	.export _int_disabled

	.export _machine_type
	.export mapport
	.export mapmod
        ; exported debugging tools
        .export _plt_monitor
	.export _plt_reboot
        .export outchar

	; banking support
	.export __bank_0_1
	.export __bank_0_2
	.export __bank_0_3
	.export __bank_0_4
	.export __bank_1_2
	.export __bank_1_3
	.export __bank_1_4
	.export __bank_2_1
	.export __bank_2_3
	.export __bank_2_4
	.export __bank_3_1
	.export __bank_3_2
	.export __bank_3_4
	.export __bank_4_1
	.export __bank_4_2
	.export __bank_4_3

	.export __stub_1
	.export __stub_2
	.export __stub_3
	.export __stub_4

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
	ld	a, #0x7F
	in	a, (0xFE)
	rra
	jr	c, _plt_monitor

_plt_reboot:
	di
	im	1
	; This sequence triggers the DivIDE Plus reset mechanism
	ld	a ,(_machine_type)
	or	a
	jr	nz, reboot_zxcf
	xor	a
	ld	i, a
	ld	a, 0xC0
	out	(0xE3),a
	halt
reboot_zxcf:
	di
	halt

plt_interrupt_all:
        ret

	.commondata

_int_disabled:
	.byte	1
_machine_type:
	.byte	1
mapmod:
	.word 0x0060		; for DivIDE Plus (RAM mode with write)
mapport:
	.word 0xFF17		; for DivIDE plus (port XX17)

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (below 0x4000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.overlay1

;	Can we get some of this into discard TODO
;
;	The memory banker will deal with the map setting
;
init_early:
	ld	(_machine_type),a
	or	a
        ret	z
	; Switch to mappings for ZXCF
	ld	bc, 0x10BF
	ld	(mapport), bc
	ld	bc, 0x0240	; or with 0x40 move on by 2
	ld	(mapmod),bc
	ret

	.common

init_hardware:
        ; set system RAM size
        ld	hl, #560
	ld	a,(_machine_type)
	or	a
	jr	nz, inith2
	ld	hl, 528; we lose bits to ResiDOS
inith2:
        ld	(_ramsize), hl
	ld	de, 112   ; 4 x 16K banked + 16K go to the OS/screen
			  ; and we lose 32K for speed so we can ldir
			  ; not to do tricky exchanges
	or	a
	sbc	hl,de
        ld	(_procmem), hl

        ; screen initialization
	push	af
	call	_vtinit
	pop	af

	; Vectors

	ld	a, 4
vecloop:
	dec	a
	push	af
	call	map_bank_a
	call	vectors
	call	map_kernel_restore
	pop	af
	jr	nz, vecloop
        ret

;	What's our vector, Victor ?

vectors:
	ld	a, 0xC3
	ld	(0) ,a
	ld	hl, null_handler
	ld	(1),hl
	ld	(0x38),a
	ld	hl, interrupt_handler
	ld	(0x39), hl
	ret

	.code

_plt_idle:
	halt
	ret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_program_vectors:
	ret

	; Swap helper. Map the page in A into the address space such
	; that swap_map() gave the correct pointer to use. Undone by
	; a map_kernel_{restore}

map_buffers:
	ld	a, 3
map_restore_kmap:
map_bank_a:
        ; bank switching procedure. On entrance:
        ;  A - bank number to set
	push	af
	ld	a, (current_map)
	ld	(ksave_map), a
	pop	af
	push	af
	call	switch_bank
	pop	af
	ret

map_save_kmap:
	ld	a,(current_map)
	ret

switch_bank:
	push	bc
	; Write the store first, that way any interrupt will restore
	; the new bank and our out will just be a no-op
        ld	(current_map), a
	ld	bc,(mapmod)		; 0x60 for DivIDE plus 0x40 for ZXCF+
	add	a, b			; have to avoid bank 0 on ZXCF+ (residos)
	or	c
	ld	bc,(mapport)		; 0x17 for DivIDE plus 0x4278 for ZXCF+
        out	(c), a
	pop	bc
        ret

map_proc:
        ld	a, h
        or	l
        jr	z, map_kernel_nosavea
	push	af
        ld	a, (hl)
	call	switch_bank
	pop	af
	ret
;
;	We always save here so that existing code works until we have a
;	clear usage of save/restore forms across the kernel
;
map_for_swap:
map_proc_save:
map_proc_always:
map_proc_always_di:
	push	af
	ld	a, (current_map)
	ld	(ksave_map), a
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
;
;	This may look odd. However the kernel is banked so any
;	invocation of kernel code in fact runs common code and the
;	common code will bank in the right kernel bits for us when it calls
;	out of common into banked code. We do a restore to handle all the
;	callers who do map_proc_always/map_kernel pairs. Probably we
;	should have some global change to map_proc_save/map_kernel_restore
;
map_kernel_di:
map_kernel:
map_kernel_nosavea:          ; to avoid double reg A saving
map_kernel_restore:
	push	af
	ld	a, (ksave_map)
	call	switch_bank
	pop	af
	ret

map_restore:
	push	af
        ld	a, (map_store)
        call	switch_bank
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
	push	af
	call	_vtoutput
	pop	af
	pop	af
	pop	af
	pop	hl
	pop	de
        ret

	.commondata

_tmpout:
	.byte 1

current_map:                ; place to store current page number. Is needed
        .byte 0               ; because we have no ability to read 7ffd port
                            ; to detect what page is mapped currently 
map_store:
        .byte 0

ksave_map:
        .byte 0

_need_resched:
        .byte 0

	.common
;
;	Banking helpers
;
;	Logical		Physical
;	0		COMMON (0x4000)
;	1		0
;	2		1
;	3		2
;
;
__bank_0_1:
	xor a		   ; switch to physical bank 0 (logical 1)
bankina0:
	;
	;	Get the target address first, otherwise we will change
	;	bank and read it from the wrong spot!
	;
	pop	hl	; Return address (points to true function address)
	ld	e, (hl)	; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl	; Restore corrected return pointer
	push	bc
	ld	bc, (current_map)	; get current bank into B
	call	switch_bank; Move to new bank
	; figure out which bank to map on the return path
	ld	a, c
	pop	bc
	or	a
	jr	z, __retmap1
	dec	a
	jr	z, __retmap2
	dec	a
	jr	z, __retmap3
	jr	__retmap4

callhl:	jp	(hl)
__bank_0_2:
	ld	a, 1	   ; logical 2 -> physical 1
	jr	bankina0
__bank_0_3:
	ld	a, 2	   ; logical 3 -> physical 2
	jr	bankina0
__bank_0_4:
	ld	a, 3	   ; logical 4 -> physical 3
	jr	bankina0

__bank_1_2:
	ld	a, 1
bankina1:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap1:
	ex	de, hl
	call	callhl		; call the function
	xor	a		; return to bank 1 (physical 0)
	jp	switch_bank
__bank_1_3:
	ld	a, 2
	jr	bankina1
__bank_1_4:
	ld	a, 3
	jr	bankina1
__bank_2_1:
	xor	a
bankina2:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap2:
	ex	de, hl
	call	callhl		; call the function
	ld	a, 1		; return to bank 2
	jp	switch_bank
__bank_2_3:
	ld	a, 2
	jr	bankina2
__bank_2_4:
	ld	a, 3
	jr	bankina2
__bank_3_1:
	xor	a
bankina3:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap3:
	ex	de, hl
	call	callhl		; call the function
	ld	a, 2		; return to bank 3
	jp	switch_bank
__bank_3_2:
	ld	a, 1
	jr	bankina3
__bank_3_4:
	ld	a, 3
	jr	bankina3

__bank_4_1:
	xor	a
bankina4:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap4:
	ex	de, hl
	call	callhl		; call the function
	ld	a, 3		; return to bank 4
	jp	switch_bank
__bank_4_2:
	ld	a, 1
	jr	bankina4
__bank_4_3:
	ld	a, 2
	jr	bankina4

;
;	Stubs need some stack munging and use DE
;

__stub_2:
	ld	a, 1
	jr	__stub_a
__stub_3:
	ld	a, 2
	jr	__stub_a
__stub_4:
	ld	a, 3
	jr	__stub_a
__stub_1:
	xor	a
__stub_a:
	pop	hl		; the return
	ex	(sp), hl	; write it over the discard
	push	bc
	ld	bc, (current_map)
	call	switch_bank
	ld	a, c
	pop	bc
	or	a
	jr	z, __stub_1_ret
	dec	a
	jr	z, __stub_2_ret
	dec	a
	jr	z, __stub_3_ret
__stub_4_ret:
	ex	de, hl
	call	callhl
	ld	a, 3
	jr	stubout
__stub_1_ret:
	ex	de, hl
	call	callhl
	xor	a
stubout:
	call	switch_bank
	pop	de
	push	de	; dummy the caller will discard
	push	de
	ret
__stub_2_ret:
	ex	de, hl	; DE is our target
	call	callhl
	ld	a, 1
	jr	stubout
__stub_3_ret:
	ex	de, hl
	call	callhl
	ld	a, 2
	jr	stubout

;
;	We know that we only ever copy between the user space and 4000-7FFF
;	or the buffers (0000-3FFF in our bank). So if we put our copiers in
;	the right bank and not common space we can just ldir stuff about
;	which is far simpler
;
        ; exported symbols
        .export	__uget
        .export	__ugetc
        .export	__ugetw

        .export	__uput
        .export	__uputc
        .export	__uputw
        .export	__uzero

;
;	We need these in overlay4 so they are in the right bank to copy disk
;	cache buffers
;
	.overlay4
;
;	The basic operations are copied from the standard one. Only the
;	blk transfers are different. uputget is a bit different as we are
;	not doing 8bit loop pairs.
;

__uputc:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld	(hl), e
	jp	map_kernel			; map the kernel back below common

__uputw:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld	(hl), e
	inc	hl
	ld	(hl),d
	jp	map_kernel

__ugetc:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	map_proc_always
        ld	l, (hl)
	ld	h, 0
	jp	map_kernel

__ugetw:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	map_proc_always
        ld	l, (hl)
	ld	h, 0
	jp	map_kernel


__uget:
	; As we have both maps live at once these are identical
__uput:
	push	bc
	ld	hl,11	; point at end of args
	add	hl,sp
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a

	ld	a, b
	or	c
	jr	z, uput_out	; no work
	call	map_proc_always
	ldir
	call	map_kernel
uput_out:
	pop	bc
	ld	hl,0
	ret

__uzero:
	push	bc
	ld	hl,6
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a, b	; check for 0 copy
	or	c
	ret	z
	call	map_proc_always
	ex	de,hl
	ld	(hl), 0
	dec	bc
	ld	a, b
	or	c
	jr	z, uz_out
	ld	e, l
	ld	d, h
	inc	de
	ldir
uz_out:
	pop	bc
	jp	map_kernel
