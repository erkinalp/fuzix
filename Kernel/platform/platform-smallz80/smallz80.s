# 1 "smallz80.S"
;
;	SmallZ80 support
;
;	This first chunk is mostly boilerplate to adjust for each
;	system.
;

	; exported symbols
	.export init_early
	.export init_hardware
	.export _program_vectors
	.export map_buffers
	.export map_kernel
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc
	.export map_proc_a
	.export map_proc_always
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export plt_interrupt_all
	.export _kernel_flag
	.export _int_disabled

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
# 1 "kernelu.def"
;	FUZIX mnemonics for memory addresses etc
;
;
;	The U_DATA address. If we are doing a normal build this is the start
;	of common memory. We do actually have a symbol for udata so
;	eventually this needs to go away
;
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256 bytes @ F000
;
;	Space for the udata of a switched out process within the bank of
;	memory that it uses. Normally placed at the very top
;
U_DATA_STASH		    .equ 0xBE00	      ; BE00-BFFF
;
;	We can't run CP/M stuff in emulation as our banks are in odd places
;
PROGBASE		    .equ 0x4000
PROGLOAD		    .equ 0x4000
;
;	For special platforms that have external memory protection hardware
;	Just say 0.
;

;
;	Set this if the platform has swap enabled in config.h
;

;
;	The number of disk buffers. Must match config.h
;
NBUFS			    .equ 5
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 35 "smallz80.S"
;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool
	.buffers

_bufpool:
	.ds 520  * NBUFS

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (kept even when we task switch)
; -----------------------------------------------------------------------------
	.commondata

;
;	Interrupt flag. This needs to be in common memory for most memory
;	models. It starts as 1 as interrupts start off.
;
_int_disabled:
	.byte	1

	.common
;
;	This method is invoked early in interrupt handling before any
;	complex handling is done. It's useful on a few platforms but
;	generally a ret is all that is needed
;
plt_interrupt_all:
	ret

;
;	If you have a ROM monitor you can get back to then do so, if not
;	fall into reboot.
;
;	Wait for a key as the monitor does a screen clear
;
_plt_monitor:
	ld	a,(_uart_base + 1)
	add	a,5
	ld	c,a
pmwait:
	in	a,(c)
	rrca
	jr	nc, pmwait
	; Fall through
;
;	Reboot the system if possible, halt if not. On a system where the
;	ROM promptly wipes the display you may want to delay or wait for
;	a keypress here (just remember you may be interrupts off, no kernel
;	mapped so hit the hardware).
;
_plt_reboot:
	di
	xor	a
	out	(0xF8),a
	rst	0

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (may be below 0x8000, only accessible when the kernel is
; mapped)
; -----------------------------------------------------------------------------
	.code
;
;	This routine is called very early, before the boot code shuffles
;	things into place. We do the ttymap here mostly as an example but
;	even that really ought to be in init_hardware.
;
init_early:
	in a,(0xF8)
	or 0x70		; All lights on
	out (0xF8),a
	ret

; -----------------------------------------------------------------------------
; DISCARD is memory that will be recycled when we exec init
; -----------------------------------------------------------------------------
	.discard
;
;	After the kernel has shuffled things into place this code is run.
;	It's the best place to breakpoint or trace if you are not sure your
;	kernel is loading and putting itself into place properly.
;
;	It's required jobs are to set up the vectors, ramsize (total RAM),
;	and procmem (total memory free to processs), as well as setting the
;	interrupt mode but *not* enabling interrupts. Many platforms also
;	program up support hardware like PIO and CTC devices here.
;
init_hardware:
	ld	hl,544			; 512 + 32
	ld	(_ramsize), hl
	ld	hl,480
	ld	(_procmem), hl

	ld	a,(0xFFC2)	; Where is the primary serial ?
	cp	0x10
	ld	a, 0x20		; For RTC refs
	jr	z, old_board
	ld	a, 0x50
old_board:
	ld	(_rtc_base),a	; Set RTC infop
	add	a,0x0D		; set up pointer for RTC config

	xor	a
	out	(c),a		; hold off, weirdness off
	ld	a,0x02
	inc	c
	out	(c),a		; 64ms, clear any irq
				; irq mode, unmasked
	ld	a,0x04
	inc	c
	out	(c),a		; test off, 24hr mode, stop/reset off

	ld	hl, 0xFFC2	; set up the uart map early
	ld	de, _uart_base + 1

	ldi
	inc	hl
	ldi
	inc	hl
	ldi
	inc	hl
	ldi
	inc	hl
	ld	a,(hl)
	ld	(_num_banks),a
	;	Ignore the expansion board info for now (floppy etc)

	; set up interrupt vectors for the kernel (also sets up common memory in page 0x000F which is unused)
	ld	hl, 0
	push	hl
	call	_program_vectors
	pop	hl

	im 1 ; set CPU interrupt mode

	ret

;
;	Bank switching unsurprisingly must be in common memory space so it's
;	always available.
;
	.commondata

mapsave:
	.byte	0	; Saved copy of the previous map (see map_save)

_kernel_flag:
	.byte	1	; We start in kernel mode

	.common
;
;	This is invoked with a NULL argument at boot to set the kernel
;	vectors and then elsewhere in the kernel when the kernel knows
;	a bank may need vectors writing to it.
;
;	FIXME: do this once early as we don't switch the low 16K
;
_program_vectors:
	; we are called, with interrupts disabled, by both newproc() and crt0
	; will exit with interrupts off
	di ; just to be sure
	pop	de ; temporarily store return address
	pop	hl ; function argument -- base page number
	push	hl ; put stack back as it was
	push	de

	call	map_proc

	; now install the interrupt vector at 0x0038
	ld	a, 0xC3 ; JP instruction
	ld	(0x0038), a
	ld	hl, interrupt_handler
	ld	(0x0039), hl

	ld	(0x0000), a
	ld	hl, null_handler   ;   to Our Trap Handler
	ld	(0x0001), hl

	; and fall into map_kernel

;
;	Mapping set up for the SmallZ80
;
;	The low 16K and high 16K are fixed, the middle 16K is switchable
;	and holds kernel or user code. The high 16K holds our common
;	(we could use either but for reboot common needs to switch in ROM
;	so it's easier to use the top)
;
;	We know the ROM mapping is already off
;
;	The _di versions of the functions are called when we know interrupts
;	are definitely off. In our case it's not useful information so both
;	symbols end up at the same code.
;
map_buffers:
	   ; for us no difference. We could potentially use a low 32K bank
	   ; for buffers but it's not clear it would gain us much value
map_kernel_restore:
map_kernel_di:
map_kernel:
	push	af
	in	a,(0xF8)
	and	0xF0		; bank 0 is kernel
	out	(0xF8),a
	pop	af
	ret
	; map_proc is called with HL either NULL or pointing to the
	; page mapping. Unlike the other calls it's allowed to trash AF
map_proc:
	ld	a, h
	or	l
	jr	z, map_kernel
map_proc_hl:
	ld	a, (hl)			; and fall through
	;
	; With a simple bank switching system you need to provide a
	; method to switch to the bank in A without corrupting any
	; other registers. The stack is safe in common memory.
	; For swap you need to provide what for simple banking is an
	; identical routine.
map_for_swap:
map_proc_a:			; used by bankfork
	push	af
	push	bc
	ld	b,a
	in	a, (0xF8)
	and	0xF0
	or	b
	out	(0xF8), a
	pop	bc
	pop	af
	ret

	;
	; Map the current process into memory. We do this by extracting
	; the bank value from u_page.
	;
map_proc_always_di:
map_proc_always:
	push af
	push hl
	ld hl, _udata + 2     
	call map_proc_hl
	pop hl
	pop af
	ret

	;
	; Save the existing mapping and switch to the kernel.
	; The place you save it to needs to be in common memory as you
	; have no idea what bank is live. Alternatively defer the save
	; until you switch to the kernel mapping
	;
map_save_kernel:
	push	af
	in	a, (0xF8)
	and	0x0F
	ld	(mapsave), a
	in	a, (0xF8)
	and	0xF0		; kernel bank 0
	out	(0xF8), a
	pop	af
	ret
	;
	; Restore the saved bank. Note that you don't need to deal with
	; stacking of banks (we never recursively use save/restore), and
	; that we may well call save and decide not to call restore.
	;
map_restore:
	push	af
	push	hl
	ld	hl, mapsave
	in	a, (0xF8)
	or	(hl)
	out	(0xF8), a
	pop	hl
	pop	af
	ret

	;
	; Used for low level debug. Output the character in A without
	; corrupting other registers. May block. Interrupts and memory
	; state are undefined
	;
outchar:
	push	af
	push	bc
	ld	a, (_uart_base + 1)
	add	a,5
	ld	c,a
twait:	in	a, (c)
	bit	5, a
	jr	z, twait
	ld	a,c
	sub	5
	ld	c,a
	pop	af
	out	(c), a
	pop	bc
	ret
