;
;	Agon Light / AgonLight2 hardware support
;

	.z180

	; exported symbols
	.export init_hardware
	.export _program_vectors
	.export map_buffers
	.export map_kernel
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc
	.export map_proc_di
	.export map_proc_a
	.export map_proc_always
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export plt_interrupt_all
	.export _int_disabled
	.export _bufpool
	.export _plt_idle
	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;
	.buffers

_bufpool:
	.ds BUFSIZE * NBUFS

; -----------------------------------------------------------------------------
; DISCARD is memory that will be recycled when we exec init
; -----------------------------------------------------------------------------
	.discard

init_hardware:
	ld	hl, 512
	ld	(_ramsize), hl
	ld	hl, 7 * 56
	ld	(_procmem), hl

	; MOS leaves UART0, VDP vsync (PB1) and I2C interrupts on
	xor	a
	out0	(UART0_IER), a
	out0	(UART1_IER), a
	out0	(I2C_CTL), a
	out0	(TMR0_CTL), a
	out0	(TMR1_CTL), a
	out0	(TMR2_CTL), a
	out0	(TMR3_CTL), a
	out0	(TMR4_CTL), a
	out0	(TMR5_CTL), a
	; PB1 back to an input. Clear the edge, then ALT1 before ALT2 so it
	; is never an output
	in0	a, (PB_DR)
	or	0x02
	out0	(PB_DR), a
	in0	a, (PB_ALT1)
	and	0xFD
	out0	(PB_ALT1), a
	in0	a, (PB_ALT2)
	and	0xFD
	out0	(PB_ALT2), a

	; UART0 to the VDP. Keep the MOS speed but MOS 3 uses RTS/CTS on
	; PD2/PD3 and the VDP stops sending if RTS drops
	in0	a, (PD_DDR)
	or	0x0C
	out0	(PD_DDR), a
	in0	a, (PD_ALT1)
	and	0xF3
	out0	(PD_ALT1), a
	in0	a, (PD_ALT2)
	or	0x0C
	out0	(PD_ALT2), a
	ld	a, 0x02			; RTS asserted
	out0	(UART0_MCTL), a
	ld	a, 0x07			; FIFOs on and cleared
	out0	(UART0_FCTL), a

	call	program_kvectors

	; IM2 with MADL clear behaves as on a Z80
	ld	hl, _vectors
	ld	de, interrupt_handler
	ld	b, 0x30
vecfill:
	ld	(hl), e
	inc	hl
	ld	(hl), d
	inc	hl
	djnz	vecfill

	ld	hl, _vectors
	ld	a, h
	ld	i, a
	im	2

	; 100Hz from PRT0: 18.432MHz / 256 / 720
	ld	a, 0xD0
	out0	(TMR0_RR_L), a
	ld	a, 0x02
	out0	(TMR0_RR_H), a
	ld	a, 0x5F			; irq, continuous, /256, reload, enable
	out0	(TMR0_CTL), a

	call	_vdp_terminal_init

	ld	a, 0x01			; Receive interrupts
	out0	(UART0_IER), a
	ret

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (kept even when we task switch)
; -----------------------------------------------------------------------------
	.common
;
;	Interrupt flag. This needs to be in common memory for most memory
;	models. It starts as 1 as interrupts start off.
;
_int_disabled:
	.byte 1

mapreg:
	.byte KERNEL_BANK	; Our map register is write only so keep a copy
mapsave:
	.byte 0		; Saved copy of the previous map (see map_save)

;
;	This method is invoked early in interrupt handling before any
;	complex handling is done.
;
plt_interrupt_all:
	ret

;
;	No monitor. Leaving terminal mode clears the screen so wait for a key
;
_plt_monitor:
	di
	ld	hl, monitor_msg
	call	outstring
monitor_key:
	in0	a, (UART0_LSR)
	rra				; data ready ?
	jr	nc, monitor_key
	in0	a, (UART0_RBR)
;
;	VDP out of terminal mode for MOS, then let the watchdog reset us
;
_plt_reboot:
	di
	ld	hl, vdp_exit
	call	outstring
	ld	a, 0x83			; WDT on, reset after 2^18 clocks
	out0	(WDT_CTL), a
reboot:
	jr	reboot

monitor_msg:
	.ascii	"[press a key to reboot]"
	.byte	0
vdp_exit:
	.byte	0x1B, 0x5F, 0x23, 0x51, 0x21, 0x24, 0	; ESC _ # Q ! $

;
;	This is invoked with a NULL argument at boot to set the kernel
;	vectors and then elsewhere in the kernel when the kernel knows
;	a bank may need vectors writing to it.
;
_program_vectors:
	di
	pop	de			; temporarily store return address
	pop	hl			; function argument -- base page number
	push	hl			; put stack back as it was
	push	de
	push	bc

	call	map_proc

	; write zeroes across all vectors
	ld	hl, 0
	ld	de, 1
	ld	bc, 0x007F		; program first 0x80 bytes only
	ld	(hl), 0x00
	ldir
	pop	bc

program_kvectors:
	ld	a, 0xC3			; JP instruction
	ld	(0x0000), a		; Must be present for NULL checker
	ld	hl, null_handler
	ld	(0x0001), hl

	ld	(0x0038), a		; Should not be used (IM2)
	ld	hl, interrupt_handler
	ld	(0x0039), hl

	ld	(0x0066), a		; Set vector for NMI
	ld	hl, nmi_handler
	ld	(0x0067), hl

	jp	map_kernel

;
;	MBASE can only be loaded in ADL mode so we go via seladl in the kernel
;	bank. Interrupts must be off as an ADL mode interrupt vectors via the
;	flash.
;
map_proc:
map_proc_di:
	ld	a, h
	or	l
	jr	z, map_kernel
	ld	a, (hl)
	jr	map_proc_a

map_proc_always:
map_proc_always_di:
	push	af
	ld	a, (_udata + U_DATA__U_PAGE)
	call	map_proc_a
	pop	af
	ret

map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push	af
map_kernel_a:
	ld	a, KERNEL_BANK
	call	map_proc_a
	pop	af
	ret

map_save_kernel:
	push	af
	ld	a, (mapreg)
	ld	(mapsave), a
	jr	map_kernel_a

map_restore:
	push	af
	ld	a, (mapsave)
	call	map_proc_a
	pop	af
	ret

map_for_swap:
map_proc_a:
	push	af
	push	bc
	ld	b, a
	ld	a, i			; P/V = IFF2
	di
	ld	a, b
	pop	bc
	jp	pe, map_proc_ei
	call	selmem
	pop	af
	ret
map_proc_ei:
	call	selmem
	pop	af
	ei
	ret

selmem:
	or	a			; bank 0 is flash
	jr	nz, selmem_go
	ld	a, KERNEL_BANK
selmem_go:
	ld	(mapreg), a
	.byte	0x5B, 0xC3		; jp.lil {KERNEL_BANK,seladl}
	.word	seladl
	.byte	KERNEL_BANK
selret:
	ret

;
;	Used for low level debug. Output the character in A without
;	corrupting other registers. May block. Interrupts and memory
;	state are undefined
;
outchar:
	push	af
outcharw:
	in0	a, (UART0_LSR)
	and	0x20			; Transmit holding register empty ?
	jr	z, outcharw
	in0	a, (UART0_MSR)
	and	0x10			; VDP ready (CTS) ?
	jr	z, outcharw
	pop	af
	out0	(UART0_THR), a
	ret

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.code

;
;	ADL mode. Must not be in common as we move it
;
seladl:
	out0	(RAM_ADDR_U), a
	.byte	0xED, 0x6D		; ld mb,a
	.byte	0x40, 0xC3		; jp.sis selret
	.word	selret

_plt_idle:
	halt
	ret

;
;	IM2 vectors in common
;
	.abs
	.org	0xFF00
_vectors:
	.ds	0x60
