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
	.export map_proc_a
	.export plt_interrupt_all
	.export _plt_reboot
	.export _plt_monitor
	.export _plt_idle
	.export _bufpool
	.export _int_disabled

	; exported debugging tools
	.export inchar
	.export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"


	.common

	.export	vector
vector:
	.word	spurious		; CTC 0
	.word	spurious		; CTC 1
	.word	interrupt_handler	; CTC 2
	.word	spurious		; CTC 3
	.word	spurious		; Spare slots
	.word	spurious
	.word	spurious
	.word	spurious
	.word	siob_txd		; SIO B then A
	.word	siob_status
	.word	siob_rx_ring
	.word	siob_special
	.word	sioa_txd
	.word	sioa_status
	.word	sioa_rx_ring
	.word	sioa_special

;=========================================================================
; Buffers
;=========================================================================
	.buffers

_bufpool:
        .ds	BUFSIZE * 4 ; adjust NBUFS in config.h in line with this

;=========================================================================
; Initialization code
;=========================================================================
	.discard
init_hardware:
	ld	hl,128
	ld	(_ramsize), hl
	ld	hl,96
	ld	(_procmem), hl

	;
	;	We run the kernel with CS1 high and user with CS1 low
	;	and the low 4K common
	;

	call	sio_install

	;
	; Defense in depth - shut everything up first
	;

	ld	a,0x43
	out	(CTC_CH0),a		; set CH0 mode
	out	(CTC_CH1),a		; set CH1 mode
	out	(CTC_CH2),a		; set CH2 mode
	out	(CTC_CH3),a		; set CH3 mode

	;
	; Set up timer for 100Hz
	; The CTC is clocked at 3.6864MHz
	;
	ld	a,0x00		; FIXME check
	out	(CTC_CH0),a	; set the CTC vector
	ld	a,0xB5
	out	(CTC_CH2),a
	ld	a,144
	out	(CTC_CH2),a	; 100 Hz

	;
	; Set up counter CH3 to count CH2 - assumes ZC2 is jumpered to TRG3
	;
	ld	a,0x47
	out	(CTC_CH3),a
	ld	a,255
	out	(CTC_CH3),a

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

	ld	a,0xFF
	out	(PIOA_C),a	; bitwise
	ld	a,0xF9		; CLK and MOSI are outputs
	out	(PIOA_C),a
	ld	a,0x07
	out	(PIOA_C),a	; no interrupts
	ld	a,0xFF
	out	(PIOB_C),a	; bitwise
	ld	a,0xF8		; SPI selects are outputs
	out	(PIOB_C),a
	ld	a,0x07
	out	(PIOB_C),a

	ld	a,>vector
	ld	i,a
	im	2
	ret

sio_setup:
	.byte	0x00
	.byte	0x18		; Reset
	.byte	0x04
	.byte	0xC4
	.byte	0x01
	.byte	0x1F
	.byte	0x03
	.byte	0xE1
	.byte	0x05
	.byte	RTS_LOW
	.byte	0x02
	.byte	0xF0		; IRQ vector written to port B

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

plt_interrupt_all:
	ret

; install interrupt vectors - no-op as in common low space
_program_vectors:
	ret

spurious:
	ei
	reti

;
;	Map the process page table pointed to via HL
;	Annoyingly we cannot map the upper 64K low 4K bank into 0000-0FFF
;	So we have a block of common ROM space we are stuck with
;
;	Kernel is 0000-BFFF	\CS0	C000-FFFF	CS1 high
;	User0 is 1000-BFFF	\CS1    C000-FFFF	CS1 high
;	User1 is 1000-BFFF	CS1	C000-FFFF	CS1 high
;
;	Settings are 0B kernel B0 user1 00 user 2
;
;
map_proc:
map_proc_di:
	ld	a,h
	or	l			; HL == 0?
	jr	z,map_kernel		; HL == 0 - map the kernel
	ld	a,(hl)
map_for_swap:
map_proc_a:
	push	af
	dec	a			; Shifted by one to avoid 0 confusion
	ld	(map_reg),a
	out	(0xEF),a
	pop	af
	ret
map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push	af
	ld	a,0x0C			; ROM 0000-CFFF, high RAM D000-FFFF
	ld	(map_reg),a
	out	(0xEF),a
	pop	af
	ret

;
;	Map the requested block for swap. In our case this is the same as
;	mapping the process as our block I/O routines just sit high
;
map_proc_always:
map_proc_always_di:
	push	af
	ld	a,(_udata + U_DATA__U_PAGE)
	call	map_proc_a
	pop	af
	ret

map_restore:
	push	af
	ld	a,(map_save)
	ld	(map_reg),a
	out	(0xEF),a
	pop	af
	ret

map_save_kernel:
	push	af
	ld	a,(map_reg)
	ld	(map_save),a
	ld	a,0x0C
	ld	(map_reg),a
	out	(0xEF),a
	pop	af
	ret

	.commondata

map_reg:
	.byte	0
map_save:
	.byte	0

_int_disabled:
	.byte 1

;
;	A little SIO helper
;
	.code

	.export _sio2_otir

_sio2_otir:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	ld	b, 0x06
	ld	c,l
	ld	hl,_sio_r
	otir
	pop	bc
	ret


	.common
;=========================================================================
; Basic console I/O
;=========================================================================

;=========================================================================
; outchar - Wait for UART TX idle, then print the char in A
; Inputs: A - character to print
; Outputs: none
;=========================================================================
outchar:
	push	af
	; wait for transmitter to be idle
ocloop_sio:
        xor	a		; read register 0
        out	(SIOA_C), a
	in	a,(SIOA_C)	; read Line Status Register
	and	0x04		; get THRE bit
	jr	z,ocloop_sio
	; now output the char to serial port
	pop	af
	out	(SIOA_D),a
	ret


;=========================================================================
; inchar - Wait for character on UART, return in A
; Inputs: none
; Outputs: A - received character, F destroyed
;=========================================================================
inchar:
        xor	a		; read register 0
        out	(SIOA_C), a
	in	a,(SIOA_C)   	; read Line Status Register
	rra			; test if data is in receive buffer
	jr	nc,inchar	; no data, wait
	in	a,(SIOA_D)   	; read the character from the UART
	ret

