;
; SAMx8 platform
;

	; exported (buffers)
	.export _bufpool

	; exported (discard)
	.export init_early
	.export init_hardware
	.export _framedet

	; exported (common)
	.export _plt_monitor
	.export _plt_reboot
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore
	.export _program_vectors
	.export outchar

	; exported (commondata)
	.export _need_resched

	; exported (code)
	.export _copy_common

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Other platforms would copy these into place within init_hardware, but for
; SAMx8, we just include the vectors in the right bit of the binary.  The
; loader will ensure they end up in the COMMON area (where they will appear
; read-only).

	.abs
	.org 0xffe0

vectors:
	.ds 0x10		; 16 spare bytes!
	.word badswi_handler	; 6809 Reserved / 6309 Trap
	.word badswi_handler	; SWI3
	.word badswi_handler	; SWI2
	.word firq_handler	; FIRQ
	.word interrupt_handler	; IRQ
	.word badswi_handler	; SWI
	.word fd_nmi_handler	; NMI
	.word badswi_handler	; Restart

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; We use the linker to place buffers just below the discard area.

	.buffers

_bufpool:
	.ds BUFSIZE*NBUFS

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Early setup in discard section.

	.discard

init_early:
	ldx #null_handler
	stx 1
	lda #0x7e
	sta 0
	rts

init_hardware:
	sta 0xffd9	; fast mode
	sta 0xffdf	; 64K RAM (loader should already have done this)
	jsr _size_ram
	; Turn on PIA CB1 (FSync interrupt)
	lda 0xff03
	ora #1
	sta 0xff03
	; 50Hz or 60Hz?
	ldx #0
	lda 0xff02
waitvb0:
	lda 0xff03
	bpl waitvb0	; wait for vsync
	lda 0xff02
waitvb2:
	leax 1,x	; time until vsync starts
	lda 0xff03
	bpl waitvb2
	stx _framedet
	jsr _vid256x192
	jmp _vtinit	; tail call

_framedet:
	.word 0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Platform code.

	.common

; void plt_monitor(void);

_plt_monitor:
	orcc #0x10
	bra _plt_monitor

; void plt_reboot(void);

_plt_reboot:
	orcc #0x50
	ldu #0xff30
	ldd #0x0001	; reset lower 32K of both tasks
	std ,u
	std 4,u
	; copy trampoline
	leay tramp_begin,pcr
	ldx #0x0400
	ldb #tramp_size
prl0:	lda ,y+
	sta ,x+
	decb
	bne prl0
	clra
	jmp 0x0400	; jump on trampoline

tramp_begin:
	; A & B are clear, U = 0xFF30 from above
	sta 0xffd4	; task 0
	sta 0xffde	; map type 0
	sta 0x0071	; cold boot flag for ROM reset handler
	std 8,u		; reset video base
	sta 15,u	; clear COMMON
	ldd #0x0203	; finish resetting page mapping
	std 2,u
	std 4,u		; correct as samx8 reuses PAGE bit
	std 6,u
	jmp [0xfffe]

tramp_size	equ	26	; need to count this manually

; typedef uint8_t irqflags_t;
; irqflags_t __hard_di(void);

___hard_di:
	tfr cc,b	; return the old irq state
	orcc #0x10
	rts

; void __hard_ei(void);
___hard_ei:
	andcc #0xef
	rts

; void __hard_irqrestore(irqflags_t f);
___hard_irqrestore:	; B holds the data
	tfr b,cc
	rts

; No-op interrupt handlers.

firq_handler:
badswi_handler:
swi2_handler:
swi3_handler:
	rti

; Called by pagemap_realloc and makeproc
; void program_vectors(uint16_t *pageptr);
_program_vectors:
	tfr d,x
	lda ,x
	sta 0xff34
	lda #0x7e
	sta 0
	ldd #null_handler
	std 1
	clr 0xff34
	rts

; Debug via printer port.
;
outchar:
	stb 0xff02
	lda 0xff20
	ora #0x02
	sta 0xff20
	anda #0xfd
	sta 0xff20
	rts

	.commondata

_need_resched:	.byte 0

	.code

; void copy_common(uint8_t page);
;
; With a COMMON bit in SAMx8, we never need to copy_common()

_copy_common:
	rts
