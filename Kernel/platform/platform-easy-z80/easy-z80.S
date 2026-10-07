; 2014-02-19 Sergey Kiselev
; RC2014 hardware specific code

        ; exported symbols
        export init_hardware
	export _program_vectors
	export map_kernel
	export map_kernel_restore
	export map_proc
	export map_buffers
	export map_buf_user
	export map_buf_user_h
	export map_kernel_di
	export map_proc_di
	export map_proc_always
	export map_proc_always_di
	export map_save_kernel
	export map_restore
	export map_for_swap
	export plt_interrupt_all
	export _copy_common
	export mpgsel_cache
	export top_bank
	export _kernel_pages
	export _plt_reboot
	export _plt_idle
	export _int_disabled

	; exported debugging tools
;	export outchar
;	export inchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

;=========================================================================
; Initialization code
;=========================================================================
	.discard

init_hardware:
        ; program vectors for the kernel
        ld hl, 0
        push hl
        call _program_vectors
        pop hl

	; Get the internal DI state right
	call ___hard_di

        ; Stop floppy drive motors
        ld a, 0x0C
        out (FDC_DOR), a

	; Play guess the serial port

	;
	; We are booted under ROMWBW, therefore use the same algorithm as
	; ROMWBW so if the probe fails we at least expect it to have failed
	; before we run.
	;
	; FIXME: see if we can cleanly ask ROMWBW for the device type
	;

	call sio_install

        ; ---------------------------------------------------------------------
	; Initialize CTC
	;
	; Need to do autodetect on this
	;
	; We must initialize all channels of the CTC. The documentation
	; states that the initial CTC state is undefined and we don't want
	; random interrupt surprises
	;
	; ---------------------------------------------------------------------

	;
	; Defence in depth - shut everything up first
	;

	ld a,0x43
	out (CTC_CH0),a			; set CH0 mode
	out (CTC_CH1),a			; set CH1 mode
	out (CTC_CH2),a			; set CH2 mode
	out (CTC_CH3),a			; set CH3 mode

	;
	; Our input clock is 921.6Khz. It would be tempting to use the CPU
	; clock and chain but the CPU clock depends on the users crystal
	; choice so we have to live with this.
	;

	ld a,0x80
	out (CTC_CH0),a	; set the CTC vector

	ld a,0x57
	out (CTC_CH2),a
	xor a
	out (CTC_CH2),a		; Divide by 256

	;
	; Set up counter CH3 as a missed event counter
	;

	ld a,0xD7
	out (CTC_CH3),a
	ld a,72		; Keep to 50Hz as used by the firmware
	out (CTC_CH3),a

        ; Done CTC Stuff
        ; ---------------------------------------------------------------------

	xor a
	ld i,a
	im 2				; set Z80 CPU interrupt mode 2
        jp _init_hardware_c             ; pass control to C, which returns for us

;=========================================================================
; Kernel code
;=========================================================================
	.code

_plt_reboot:
        ; We need to map the ROM back in -- ideally into every page.
        ; This little trick based on a clever suggestion from John Coffman.
        di
        ld hl, MPGENA*256+0xD3          ; OUT (MPGENA), A
        ld (0xFFFE), hl                 ; put it at the very top of RAM
        xor a                           ; A=0
        jp 0xFFFE                       ; execute it; PC then wraps to 0

_plt_idle:
	halt
	ret


;=========================================================================
; Common Memory (0xF000 upwards)
;=========================================================================
	.common

;=========================================================================

_int_disabled:
	.byte 1

spurious:
	reti

plt_interrupt_all:
	ret

; install interrupt vectors
_program_vectors:
	di
	pop de				; temporarily store return address
	pop hl				; function argument -- base page number
	push hl				; put stack back as it was
	push de

	; At this point the common block has already been copied
	call map_proc

	; now install the interrupt vector at 0x0038 (shouldn't be used)

	ld a,0xC3			; JP instruction
	ld (0x0038),a
	ld hl,interrupt_handler
	ld (0x0039),hl

	ld (0x0000),a
	ld hl,null_handler		; to Our Trap Handler
	ld (0x0001),hl

	ld (0x0066),a			; Set vector for NMI
	ld hl,nmi_handler
	ld (0x0067),hl

	; IM2 vector for the CTC
	ld hl, spurious
	ld (0x80),hl			; CTC vectors
	ld (0x82),hl
	ld (0x84),hl
	ld hl, interrupt_handler	; Standard tick handler
	ld (0x86),hl

	call sio_set_vectors

	jr map_kernel

;=========================================================================
; Memory management
; - kernel pages:     32 - 34
; - common page:      35
; - user space pages: 36 - 63
;=========================================================================

;=========================================================================
; map_proc_always - map process pages
; Inputs: page table address in U_DATA__U_PAGE
; Outputs: none; all registers preserved
;=========================================================================
map_proc_always:
map_proc_always_di:
	push hl
	ld hl,_udata + U_DATA__U_PAGE
        jr map_proc_2_pophl_ret

map_buf_user:
	push hl
	ld hl,(_udata + U_DATA__U_PAGE)
	ld h,36
	ld (_ubuffer_pages),hl
	ld hl,(_udata+U_DATA__U_PAGE+2)
	ld (_ubuffer_pages+2),hl
	ld hl,_ubuffer_pages
        jr map_proc_2_pophl_ret

map_buf_user_h:
	push hl
	ld hl,(_udata + U_DATA__U_PAGE)
	ld (_ubuffer_pages),hl
	ld hl,(_udata + U_DATA__U_PAGE+2)
	ld l,36
	ld (_ubuffer_pages + 2),hl
	ld hl,_ubuffer_pages
        jr map_proc_2_pophl_ret

;=========================================================================
; map_proc - map process or kernel pages
; Inputs: page table address in HL, map kernel if HL == 0
; Outputs: none; A and HL destroyed
;=========================================================================
map_proc:
map_proc_di:
	ld a,h
	or l				; HL == 0?
	jr nz,map_proc_2		; HL == 0 - map the kernel

;=========================================================================
; map_kernel - map kernel pages
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_kernel:
map_kernel_di:
map_kernel_restore:
	push hl
	ld hl,_kernel_pages
        jr map_proc_2_pophl_ret

;=========================================================================
; map_buffers - map kernel with disk buffers at 0x4000-0x7FFF
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_buffers:
	push hl
	ld hl,_kernelbuf_pages
        jr map_proc_2_pophl_ret

;=========================================================================
; map_proc_2 - map process or kernel pages
; Inputs: page table address in HL
; Outputs: none, HL destroyed
;=========================================================================
map_proc_2:
	push de
	push af

	ld de,mpgsel_cache		; paging registers are write only
					; so cache their content in RAM
	ld a,(hl)			; memory page number for bank 0
	ld (de),a
	out (MPGSEL_0),a		; set bank 0
	inc hl
	inc de
	ld a,(hl)			; memory page number for bank 1
	ld (de),a
	out (MPGSEL_1),a		; set bank 1
	inc hl
	inc de
	ld a,(hl)			; memory page number for bank 2
	ld (de),a
	out (MPGSEL_2),a		; set bank 2

	pop af
	pop de
	ret

;=========================================================================
; map_restore - restore a saved page mapping
; Inputs: none
; Outputs: none, all registers preserved
;=========================================================================
map_restore:
	push hl
	ld hl,map_savearea
map_proc_2_pophl_ret:
	call map_proc_2
	pop hl
	ret

;=========================================================================
; map_save_kernel - save the current page mapping to map_savearea and
; switch to kernel maps
; Inputs: none
; Outputs: none
;=========================================================================
map_save_kernel:
	push hl
	ld hl,(mpgsel_cache)
	ld (map_savearea),hl
	ld hl,(mpgsel_cache+2)
	ld (map_savearea+2),hl
	ld hl,_kernel_pages
	jr map_proc_2_pophl_ret

;=========================================================================
; map_for_swap - map a page into a bank for swap I/O
; Inputs: none
; Outputs: none
;
; The caller will later map_kernel to restore normality
;
; We use 0x4000-0x7FFF so that all the interrupt stuff is mapped.
;
;=========================================================================
map_for_swap:
	ld (mpgsel_cache + 1),a
	out (MPGSEL_1),a
	ret

_copy_common:
	pop hl
	pop de
	push de
	push hl
	push bc
	ld a,e
	call map_for_swap
	ld hl,0xEA00
	ld de,0x2A00
	ld bc,0x1600
	ldir
	pop bc
	jr map_kernel


; MPGSEL registers are read only, so their content is cached here
mpgsel_cache:
	.byte	0,0,0
top_bank:	; the shared tricks code needs this name for cache+3
	.byte	0

; kernel page mapping
_kernel_pages:
	.byte	32,33,34,35

; kernel page mapping with buffer window
_kernelbuf_pages:
	.byte	32,36,34,35

_ubuffer_pages:
	.byte	0,0,0,0
; memory page mapping save area for map_save/map_restore
map_savearea:
	.byte	0,0,0,0

;=========================================================================
; Basic console I/O
;=========================================================================

#if 0
;=========================================================================
; outchar - Wait for UART TX idle, then print the char in A
; Inputs: A - character to print
; Outputs: none
;=========================================================================
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

;=========================================================================
; inchar - Wait for character on UART, return in A
; Inputs: none
; Outputs: A - received character, F destroyed
;=========================================================================
inchar:
inchar_s:
        xor a                           ; read register 0
        out (SIOA_C), a
	in a,(SIOA_C)   		; read Line Status Register
	and 0x01			; test if data is in receive buffer
	jr z,inchar_s			; no data, wait
	in a,(SIOA_D)   		; read the character from the UART
	ret
;=========================================================================
;
;	Logic for IM2 interrupt driven SIO
;
;=========================================================================

	.area _SERIALDATA

	export _sio_state
	export _sio_dropdcd
	export _sio_rxl
	export _sio_txl

; These are laid out and exposed as arrays to C
_sio_wr5:
_sioa_wr5:
	.byte 0xEA		; DTR, 8bit, tx enabled
_siob_wr5:
	.byte 0xEA		; DTR, 8bit, tx enabled
_sio_flow:
_sioa_flow:
	.byte 0			; Flow starts off
_siob_flow:
	.byte 0			; Flow starts off
_sio_state:
_sioa_state:
	.byte 0			; Last status report
_siob_state:
	.byte 0			; Last status report
_sio_dropdcd:
_sioa_dropdcd:
	.byte 0			; DCD dropped since last checked
_siob_dropdcd:
	.byte 0			; DCD dropped since last checked
_sio_rxl:
_sioa_rxl:
	.byte 0
_siob_rxl:
	.byte 0
_sio_txl:
_sioa_txl:
	.byte 0
_siob_txl:
	.byte 0

	.include "../../dev/z80sio.s"

sio_ports a
sio_ports b

	.area _COMMONMEM

;
;	We don't do any clever IRQ re-entry tricks so we can use the istack.
;	If we ever do soft interrupts and take the sio during a timer int
;	we will need a small (16 byte or so) private sio work stack and to
;	be very careful with our stack handling on switches.
;
sio_sp:	.word 0

.macro switch
	ld (sio_sp),sp
	ld sp,istack_top
	call map_save_kernel
.endm

.macro switchback
	call map_restore
	ld sp,(sio_sp)
.endm

sio_handler_im2	a, SIOA_C, SIOA_D, reti
sio_handler_im2 b, SIOB_C, SIOB_D, reti
#endif
