;
;	Rhyophyre platform code
;

        .z180

        ; exported symbols
        .export init_early
        .export init_hardware
        .export inchar
        .export outchar
        .export plt_interrupt_all
	.export _plt_idle
        .export _bufpool

#include "kernelu.def"
#include "../../cpu-z180/z180.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; Buffers
; -----------------------------------------------------------------------------
	.buffers
_bufpool:
        .ds BUFSIZE * 4 ; adjust NBUFS in config.h in line with this

; -----------------------------------------------------------------------------
; Initialisation code
; -----------------------------------------------------------------------------
	.discard
init_early:
	ld a,0x80
	out (0x80),a		; ROM off
        jp z180_init_early

init_hardware:
        ; enable ASCI interrupts
        in0 a, (ASCI_STAT0)
        or 0x08                ; enable ASCI0 receive interrupts
        out0 (ASCI_STAT0), a
        in0 a, (ASCI_ASEXT0)
        and 0x7f               ; disable RDRF interrupt inhibit
        out0 (ASCI_ASEXT0), a
        in0 a, (ASCI_STAT1)
        or 0x08                ; enable ASCI1 receive interrupts
        out0 (ASCI_STAT1), a
        in0 a, (ASCI_ASEXT1)
        and 0x7f               ; disable RDRF interrupt inhibit
        out0 (ASCI_ASEXT1), a

        jp z180_init_hardware

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK
; -----------------------------------------------------------------------------
	.common

; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
outchar:
        push bc
        ld b, a
        ; wait for transmitter to be idle
ocloop: in0 a, (ASCI_STAT0)
        bit 1, a        ; and 0x02
        jr z, ocloop    ; loop while busy
        ; now output the char to serial port
        ld a, b
        out0 (ASCI_TDR0), a
        pop bc
        ret

; inchar: Wait for character on UART, return in A
; destroys: AF
inchar:
        in0 a, (ASCI_STAT0)
        rlca
        jr nc, inchar
        in0 a, (ASCI_RDR0)
plt_interrupt_all:
        ret

;----------------------------------------------------------------------------
; IDLING
;----------------------------------------------------------------------------
	.code

_plt_idle:
	halt
	ret
