        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
        .export plt_interrupt_all

        .export map_kernel
        .export map_proc_always
        .export map_proc
        .export map_kernel_di
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_proc_save
	.export map_kernel_restore
	.export map_buffers
	.export map_for_swap
	.export map_bank_a
	.export map_save_kmap
	.export map_restore_kmap
	.export map_buffers

	.export current_map
	.export switch_bank

        .export _need_resched
	.export _int_disabled

        ; exported debugging tools
        .export _plt_monitor
	.export _plt_reboot
        .export outchar

	; banking support
	.export __bank_0_1
	.export __bank_0_2
	.export __bank_0_3
	.export __bank_1_0
	.export __bank_1_2
	.export __bank_1_3
	.export __bank_2_0
	.export __bank_2_1
	.export __bank_2_3
	.export __bank_3_0
	.export __bank_3_1
	.export __bank_3_2

	.export __stub_0
	.export __stub_1
	.export __stub_2
	.export __stub_3

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; Base address of SIO/2 chip 0x00

SIOA_D		.equ	0x00
SIOB_D		.equ	0x01
SIOA_C		.equ	0x02
SIOB_C		.equ	0x03


; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (above 0xC000)
; -----------------------------------------------------------------------------
        .common

_plt_monitor:
_plt_reboot:
	di
	xor a
	out (0x3F),a
	out (0x3E),a
	out (0x38),a		; ROM in
	rst 0

plt_interrupt_all:
        ret

	.commondata

_int_disabled:
	.byte 1

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (below 0x4000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------

	.overlay1

;
;	The memory banker will deal with the map setting
;
init_early:
	ret

	.common

init_hardware:
	ld hl,sio_setup
	ld bc,0x0A00 + SIOA_C		; 10 bytes to SIOA_C
	otir

	ld hl,#sio_setup
	ld bc,0x0A00 + SIOB_C		; and to SIOB_C
	otir

        ; set system RAM size
        ld hl, 64		; 64K usable, other 64K is not wired
        ld (_ramsize), hl
        ld hl, 48		; 4 x 16K banked + 16K common + 32K
				; as we copy in/out as rather than exchange
        ld (_procmem), hl

	; Add the vectors to the low RAM
	call map_proc_always
	ld a,0xC3
	ld (0),a
	ld hl,null_handler
	ld (1),hl
	ld (0x38),a
	ld hl,interrupt_handler
	ld (0x39),hl
	call map_kernel_restore

	im 1
	ret

	.data

RTS_LOW	.equ	0xEA

sio_setup:
	.byte 0x00
	.byte 0x18		; Reset
	.byte 0x04
	.byte 0xC4
	.byte 0x01
	.byte 0x19		; We want carrier events
	.byte 0x03
	.byte 0xE1
	.byte 0x05
	.byte RTS_LOW

	.code
;
;	A little SIO helper
;
	.export _sio2_otir

_sio2_otir:
	ld hl,4
	add hl,sp
	push bc
	ld c,(hl)
	ld b,0x06
	ld hl,_sio_r
	otir
	pop bc
	ret


;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_program_vectors:
	ret

	; Swap helper. Map the page in A into the address space such
	; that swap_map() gave the correct pointer to use. Undone by
	; a map_kernel_{restore}

map_bank_a:
        ; bank switching procedure. On entrance:
        ;  A - bank number to set
	push af
	ld a, (current_map)
	ld (ksave_map), a
	pop af
	; Then fall through to set the bank up

map_restore_kmap:
switch_bank:
	; Write the store first, that way any interrupt will restore
	; the new bank and our out will just be a no-op
        ld (current_map), a
	out (0x3F),a		; bank in bit 0
	rrca
	out (0x3E),a		; bank in bit 1
	rlca
	rlca			; ROM/RAM in high bit
        out (0x38), a
        ret

map_proc:
        ld a, h
        or l
        jr z, map_kernel_nosavea
	push af
        ld a, (hl)
	or 0x80			; ROM off
	call switch_bank
	pop af
	ret
;
;	We always save here so that existing code works until we have a
;	clear usage of save/restore forms across the kernel
;
map_proc_save:
map_proc_always:
map_proc_always_di:
	push af
	ld a, (current_map)
	ld (ksave_map), a
	or 0x80
	ld (current_map),a
	call switch_bank
	pop af
	ret

;
;	Save and switch to kernel
;
map_save_kernel:
	push af
        ld a, (current_map)
        ld (map_store), a
	pop af
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
	push af
	ld a, (ksave_map)
	call switch_bank
	pop af
	ret

; This will be matched by a map_kernel so save the current state so we put
; it back correctly
map_buffers:
	push af
	ld a,(current_map)
	ld (ksave_map),a
	pop af
	ret

map_restore:
	push af
        ld a, (map_store)
        call switch_bank
	pop af
	ret

map_save_kmap:
	ld a,(current_map)
	ret

; Map out ROM and ensure the matching map_kernel is ok
map_for_swap:
	push af
	ld a,(current_map)
	ld (ksave_map),a
	or 0x80
	call switch_bank
	pop af
	ret
;
; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
;
outchar:
	push af
	; wait for transmitter to be idle
ocloop_sio:
        xor a                   ; read register 0
        out (SIOA_C), a
	in a,(SIOA_C)		; read Line Status Register
	and 0x04			; get THRE bit
	jr z,ocloop_sio
	; now output the char to serial port
	pop af
	out (SIOA_D),a
	ret

	.commondata
_tmpout:
	.byte 1

current_map:                ; place to store current page number. Is needed
        .byte 0x00          ; as we can't detect what page is mapped currently
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
;	0		COMMON (0xC000) or CODE or DISCARD
;	1		0
;	2		1
;	3		2
;
;	Calls to code we don't bank track. This means calls from code
;	we must bank track.
;
__bank_0_1:		; From common to OVERLAY1
	xor a		   ; switch to physical bank 0 (logical 1)
bankina0:
	;
	;	Get the target address first, otherwise we will change
	;	bank and read it from the wrong spot!
	;
	pop hl		   ; Return address (points to true function address)
	ld e, (hl)	   ; DE = function to call
	inc hl
	ld d, (hl)
	inc hl
	push hl		   ; Restore corrected return pointer
	push bc
	ld bc, (current_map)	; get current bank into C
	call switch_bank   ; Move to new bank
	; figure out which bank to map on the return path
	ld a, c
	pop bc
	or a
	jr z, __retmap1
	dec a
	jr z, __retmap2
	jr  __retmap3

callhl:	jp (hl)
__bank_0_2:		   ; from common to OVERLAY2
	ld a, #0x01	   ; logical 2 -> physical 1
	jr bankina0
__bank_0_3:		   ; from common to OVERLAY3
	ld a, #0x02	   ; logical 3 -> physical 2
	jr bankina0

__bank_1_0:		   ; from 1 to common
			   ; needed but might get the wrong segment back
	xor a		   ; TODO: fix properly - for now do a pointless switch
	jr bankina1
__bank_1_2:
	ld a, #0x01
bankina1:
	pop hl		   ; Return address (points to true function address)
	ld e, (hl)	   ; DE = function to call
	inc hl
	ld d, (hl)
	inc hl
	push hl		   ; Restore corrected return pointer
	call switch_bank   ; Move to new bank
__retmap1:
	ex de, hl
	call callhl	   ; call the function
	xor a	   ; return to bank 1 (physical 0)
	jp switch_bank
__bank_1_3:
	ld a, #0x02
	jr bankina1
__bank_2_0:		   ; from 2 to common
			   ; needed but might get the wrong segment back
	xor a		   ; TODO: fix properly - for now do a pointless switch
	jr bankina2
__bank_2_1:
	xor a
bankina2:
	pop hl		   ; Return address (points to true function address)
	ld e, (hl)	   ; DE = function to call
	inc hl
	ld d, (hl)
	inc hl
	push hl		   ; Restore corrected return pointer
	call switch_bank   ; Move to new bank
__retmap2:
	ex de, hl
	call callhl	   ; call the function
	ld a, #0x01	   ; return to bank 2
	jp switch_bank
__bank_2_3:
	ld a, #0x02
	jr bankina2
__bank_3_0:		   ; from 3 to common
			   ; needed but might get the wrong segment back
	xor a		   ; TODO: fix properly - for now do a pointless switch
	jr bankina3
__bank_3_1:
	xor a
bankina3:
	pop hl		   ; Return address (points to true function address)
	ld e, (hl)	   ; DE = function to call
	inc hl
	ld d, (hl)
	inc hl
	push hl		   ; Restore corrected return pointer
	call switch_bank   ; Move to new bank
__retmap3:
	ex de, hl
	call callhl	   ; call the function
	ld a, #0x02	   ; return to bank 3
	jp switch_bank
__bank_3_2:
	ld a, #0x01
	jr bankina3
__bank_3_4:
	ld a, #0x03
	jr bankina3

__stub_2:
	ld a,1
	jr stubop
__stub_3:
	ld a,2
	jr stubop
__stub_0:
	pop hl		; the return
	ex (sp), hl	; write it over the discard
	ld bc, (current_map)
	jr stubc
__stub_1:
	xor a
stubop:
	pop hl		; the return
	ex (sp), hl	; write it over the discard
	push bc
	ld bc, (current_map)
	call switch_bank
stubc:
	ex de, hl	; DE is our target now into HL
	ld a, c
	pop bc
	or a
	jr z, __stub_1_ret
	dec a
	jr z, __stub_2_ret
	jr __stub_3_ret
__stub_1_ret:
	call callhl
	xor a
stubout:
	call switch_bank
	pop de
	push de		; dummy the caller will discard
	push de		; FIXME don't we need to use BC and can't we get
	ret		; rid of all non 0_x stubs ?
__stub_2_ret:
	call callhl
	ld a,#0x01
	jr stubout
__stub_3_ret:
	call callhl
	ld a,#0x02
	jr stubout
;
;	We know that we only ever copy between the user space and 4000-7FFF
;	or the buffers (0000-3FFF in our bank). So if we put our copiers in
;	the right bank and not common space we can just ldir stuff about
;	which is far simpler
;
        ; exported symbols
        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

	.export  map_proc_always
	.export  map_kernel

;
;	We need these in common
;

	.common
;
;	The basic operations are copied from the standard one. Only the
;	blk transfers are different. uputget is a bit different as we are
;	not doing 8bit loop pairs.
;
uputget:
        ; load DE with the byte count
        ld c, (ix + 4) ; byte count
        ld b, (ix + 5)
	ld a, b
	or c
	ret z		; no work
        ; load HL with the source address
        ld l, (ix + 0) ; src address
        ld h, (ix + 1)
        ; load DE with destination address (in userspace)
        ld e, (ix + 2)
        ld d, (ix + 3)
	ret	; 	Z is still false

__uputc:
	ld hl,4
	add hl,sp
	ld a,(hl)
	inc hl
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	call map_proc_always
	ld (de), a
uputc_out:
	jp map_kernel			; map the kernel back below common

__uputw:
	ld hl,7
	add hl,sp
	ld d,(hl)
	dec hl
	ld e,(hl)
	dec hl
	ld a,(hl)
	dec hl
	ld l,(hl)
	ld h,a
	call map_proc_always
	ex de,hl
	ld (hl),e
	inc hl
	ld (hl),d
	jp map_kernel

__ugetc:
	ld hl,4
	add hl,sp
	ld e,(hl)
	inc hl
	ld d,(hl)
	call map_proc_always
        ld a, (de)
	ld h,0
	ld l,a
	jp map_kernel

__ugetw:
	ld hl,4
	add hl,sp
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	call map_proc_always
        ld e, (hl)
	inc hl
	ld d, (hl)
	ex de,hl
	jp map_kernel

__uput:
	push ix
	push bc
	ld ix, 8
	add ix, sp
	call uputget			; source in HL dest in DE, count in BC
	jr z, uput_out			; but count is at this point magic
	call map_proc_always
	ldir
uput_out:
	call map_kernel
	pop bc
	pop ix
	ld hl, #0
	ret

__uget:
	push ix
	push bc
	ld ix, 8
	add ix, sp
	call uputget			; source in HL dest in DE, count in BC
	jr z, uput_out			; but count is at this point magic
	call map_proc_always
	ldir
	jr uput_out

;
__uzero:
	ld hl,4
	add hl,sp
	push bc
	ld e,(hl)
	inc hl
	ld d,(hl)
	inc hl
	ld c,(hl)
	inc hl
	ld b,(hl)

	ld a, b	; check for 0 copy
	or c
	jr z, nowork
	call map_proc_always
	ex de,hl
	ld (hl), 0
	dec bc
	ld a, b
	or c
	jr z,nowork
	ld e, l
	ld d, h
	inc de
	ldir
nowork:
	pop bc
	jp map_kernel

;
;	IDE helpers
;
	.export _devide_write_data
	.export _devide_read_data

map:
	ld	hl,8	; 4 for the C call offset, 2 for B 2 for the map call
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	bc,IDE_REG_DATA
	ld	a,(_td_raw)
	or	a
	ret	z
	dec	a
	jp	z,map_proc_always
	ld	a,(_td_page)
	jp	map_for_swap

_devide_write_data:
	push	bc
	call	map
	otir
	otir
	jr	ide_out
_devide_read_data:
	push	bc
	call	map
	inir
	inir
ide_out:
	pop	bc
	ld	a,(_td_raw)
	or	a
	ret	z
	jp	map_kernel

;
;	Misc
;
	.export _plt_idle
_plt_idle:
	halt
	ret
