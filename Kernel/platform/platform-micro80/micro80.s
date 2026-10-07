# 1 "micro80.S"
        ; exported symbols
        .export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_proc
	.export map_proc_always
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc_di
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export map_buffers
	.export plt_interrupt_all
	.export _plt_reboot
	.export _plt_monitor
	.export _plt_idle
	.export _bufpool
	.export _int_disabled

	; exported debugging tools
	.export inchar
	.export outchar
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes @ 0xC000
Z80_TYPE		.equ	0	; CMOS

Z80_MMU_HOOKS		.equ 0

CONFIG_SWAP		.equ 1

PROGBASE		.equ	0x1000
PROGLOAD		.equ	0x1000

; Mnemonics for I/O ports etc

; Z80 CTC ports
CTC_CH0		.equ	0x10	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x11	; CTC channel 1 (periodic interrupts)
CTC_CH2		.equ	0x12	; CTC channel 2
CTC_CH3		.equ	0x13	; CTC channel 3


SIOA_D		.equ	0x18
SIOA_C		.equ	0x19
SIOB_D		.equ	0x1A
SIOB_C		.equ	0x1B
RTS_LOW		.equ	0xEA

PIOA_D		.equ	0x1C
PIOA_C		.equ	0x1D
PIOB_D		.equ	0x1E
PIOB_C		.equ	0x1F
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 30 "micro80.S"
;=========================================================================
; Buffers
;=========================================================================
	.buffers

_bufpool:
        .ds 520  * 4 ; adjust NBUFS in config.h in line with this

;=========================================================================
; Initialization code
;=========================================================================
	.discard
init_hardware:
	ld hl,128
	ld (_ramsize), hl
	ld hl,60
	ld (_procmem), hl

	ld a,3
	out (0xEE),a
	in a,(0xEF)
	and 0xFC			; make sure CS lines are high
	out (0xEF),a
	ld a,2
	out (0xEE),a
	ld a,0xF0			; CS1 is low for 1000-FFFF
	out (0xEF),a

	ld a,3				; set the register to MCR
	out (0xEE),a			; for speed

	;
	;	We run the kernel with CS1 high and user with CS1 low
	;	and the low 4K common
	;

	call sio_install

	ld hl,siob_txd
	ld (0xff0),hl			; SIO B TX empty
	ld hl,siob_status
	ld (0xff2),hl			; SIO B External status
	ld hl,siob_rx_ring
	ld (0xff4),hl			; SIO B Receive
	ld hl,siob_special
	ld (0xff6),hl			; SIO B Special
	ld hl,sioa_txd
	ld (0xff8),hl			; SIO A TX empty
	ld hl,sioa_status
	ld (0xffa),hl			; SIO A External status
	ld hl,sioa_rx_ring
	ld (0xffc),hl			; SIO A Received
	ld hl,sioa_special
	ld (0xffe),hl			; SIO A Special

	; write zeroes across all vectors
	ld hl,0
	ld de,1
	ld bc,0x007f			; program first 0x80 bytes only
	ld (hl),0x00
	ldir

	; now install the interrupt vector at 0x0038
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

	;
	; Defense in depth - shut everything up first
	;

	ld a,0x43
	out (CTC_CH0),a			; set CH0 mode
	out (CTC_CH1),a			; set CH1 mode
	out (CTC_CH2),a			; set CH2 mode
	out (CTC_CH3),a			; set CH3 mode

	;
	; Set up timer for 100Hz
	; The CTC is clocked at 3.6864MHz
	;
	; IM2 vector for the CTC
	ld hl, spurious
	ld (0xfe0),hl			; CTC vectors
	ld (0xfe2),hl
	ld (0xfe6),hl
	ld hl, interrupt_handler	; Standard tick handler
	ld (0xfe4),hl

	ld a,0xE0
	out (CTC_CH0),a	; set the CTC vector
	ld a,0xB5
	out (CTC_CH2),a
	ld a,144
	out (CTC_CH2),a	; 100 Hz

	;
	; Set up counter CH3 to count CH2 - assumes ZC2 is jumpered to TRG3
	;
	ld a,0x47
	out (CTC_CH3),a
	ld a,255
	out (CTC_CH3),a

        ; Done CTC Stuff
        ; ---------------------------------------------------------------------

	;
	;	PIO
	;
	;	A 7-3:	Joystick
	;	A 2-0:	SPI (CLK, MOSI, MISO)
	;	B 7-3:  Joystick
	;	B 2-0:	SPI select
	;

	ld a,0xFF
	out (PIOA_C),a		; bitwise
	ld a,0xF9		; CLK and MOSI are outputs
	out (PIOA_C),a
	ld a,0x07
	out (PIOA_C),a		; no interrupts
	ld a,0xFF
	out (PIOB_C),a		; bitwise
	ld a,0xF8		; SPI selects are outputs
	out (PIOB_C),a
	ld a,0x07
	out (PIOB_C),a

	ld a,0x0f
	ld i,a
	im 2
	ret

sio_setup:
	.byte 0x00
	.byte 0x18		; Reset
	.byte 0x04
	.byte 0xC4
	.byte 0x01
	.byte 0x1F
	.byte 0x03
	.byte 0xE1
	.byte 0x05
	.byte RTS_LOW
	.byte 0x02
	.byte 0xF0		; IRQ vector written to port B

;=========================================================================
; Kernel code
;=========================================================================

	.code

_plt_idle:
	halt
	ret

	.common

_plt_monitor:
_plt_reboot:
	; FIXME: we can flip the CS lines around and also generate a reset
	; on the bus too.
	di
	halt

_int_disabled:
	.byte 1

plt_interrupt_all:
	ret

; install interrupt vectors - no-op as in common low space
_program_vectors:
	ret

spurious:
	ei
	reti

;=========================================================================
; Memory management
;=========================================================================

;=========================================================================
; map_proc - map process or kernel pages
; Inputs: page table address in HL, map kernel if HL == 0
; Outputs: none; A and HL destroyed
;=========================================================================
map_proc:
map_proc_di:
	ld a,h
	or l				; HL == 0?
	jr z,map_kernel			; HL == 0 - map the kernel

	; fall through

;=========================================================================
; map_for_swap - map a page into a bank for swap I/O
; Inputs: none
; Outputs: none
;
; The caller will later map_kernel to restore normality
;
;=========================================================================
map_for_swap:

	; fall through

;=========================================================================
; map_proc_always - map process pages
; Inputs: page table address in 2     
; Outputs: none; all registers preserved
;=========================================================================
map_proc_always:
map_proc_always_di:
	push af
	in a,(0xEF)
	or 0x02		; CS1 enable for user space
	out (0xEF),a
	pop af
	ret

;=========================================================================
; map_kernel - map kernel pages
; map_buffers - map kernel and buffers (no difference for us)
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push af
	in a,(0xEF)
	and 0xFD		; CS1 disable for kernel
	out (0xEF),a
	pop af
	ret

;=========================================================================
; map_restore - restore a saved page mapping
; Inputs: none
; Outputs: none, all registers preserved
;=========================================================================
map_restore:
	push af
	ld a,(map_save)
	out (0xEF),a
	pop af
	ret

;=========================================================================
; map_save - save the current page mapping to map_savearea
; Inputs: none
; Outputs: none
;=========================================================================
map_save_kernel:
	push af
	in a,(0xEF)
	ld (map_save),a
	and 0xFD
	out (0xEF),a
	pop af
	ret


map_save:
	.byte 0
;
;	A little SIO helper
;
	.export _sio2_otir

_sio2_otir:
	pop de
	pop hl
	push hl
	push de
	push bc
	ld b, 0x06
	ld c,l
	ld hl,_sio_r
	otir
	pop bc
	ret


;=========================================================================
; Basic console I/O
;=========================================================================

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
        xor a                           ; read register 0
        out (SIOA_C), a
	in a,(SIOA_C)   		; read Line Status Register
	and 0x01			; test if data is in receive buffer
	jr z,inchar			; no data, wait
	in a,(SIOA_D)   		; read the character from the UART
	ret
