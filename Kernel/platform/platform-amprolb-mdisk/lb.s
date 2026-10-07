# 1 "lb.S"
        ; exported symbols
        .export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_proc
	.export map_proc_a
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
U_DATA_STASH		.equ	0x7E00	; 512 bytes at top of pageable
Z80_TYPE		.equ	0	; CMOS

Z80_MMU_HOOKS		.equ 0

CONFIG_SWAP		.equ 1

PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Mnemonics for I/O ports etc

CONSOLE_RATE		.equ	9600

CPU_CLOCK_KHZ		.equ	4000

B_RST	.equ	0x80
B_AACK	.equ	0x10
B_ASEL	.equ	0x04
B_ABUS	.equ	0x01

B_BUSY	.equ	0x40
B_MSG	.equ	0x10
B_CD	.equ	0x08
B_IO	.equ	0x04

B_PHAS	.equ	0x08

ncr_base	.equ	0x20
ncr_data	.equ	ncr_base
ncr_cmd		.equ	ncr_base + 1
ncr_mod		.equ	ncr_base + 2
ncr_tgt		.equ	ncr_base + 3
ncr_bus		.equ	ncr_base + 4
ncr_st		.equ	ncr_base + 5
ncr_dma_w	.equ	ncr_base + 5
ncr_int		.equ	ncr_base + 7
ncr_dma_r	.equ	ncr_base + 7
ncr_dack	.equ	ncr_base + 8
DARTA_D		.equ	0x80
DARTA_C		.equ	0x84
DARTB_D		.equ	0x88
DARTB_C		.equ	0x8C

CTC_CH0		.equ	0x40
CTC_CH1		.equ	0x50
CTC_CH2		.equ	0x60
CTC_CH3		.equ	0x70
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 30 "lb.S"
;=========================================================================
; Buffers
;=========================================================================

	.buffers
	.export kernel_endmark

_bufpool:
        .ds 520  * 4 ; adjust NBUFS in config.h in line with this
;
;	So we can check for overflow
;
kernel_endmark:

;=========================================================================
; Initialization code
;=========================================================================
        .common			; need this in the high space
init_hardware:

	; Configure serial first of all

	ld hl,dart_setup
	ld bc,0xA00 + DARTA_C		; 10 bytes to SIOA_C
	otir
	ld hl,dart_setup
	ld bc,0x0C00 + DARTB_C		; and to SIOB_C
	otir

	; Shut the CTC up just in case

	ld a,0x03
	out (CTC_CH0),a
	out (CTC_CH1),a
	out (CTC_CH2),a
	out (CTC_CH3),a

	; Set for 9600 baud serial

	ld a,0x47
	out (CTC_CH0),a
	ld a,0x13
	out (CTC_CH0),a
	ld a,0x47
	out (CTC_CH1),a
	ld a,0x13
	out (CTC_CH1),a

	; If the MDISK is present then 0x30 controls banking, if not then
	; it doesn't do anything. Detect this because once it works and
	; we fix some of the core issues with this we want to fold the
	; targets together.

	xor a
	out (0x30),a
	ld h,a
	ld l,a
	ld (hl),a
	ld a,2
	out (0x30),a			; block 2 (1 is high 32K)
	ld (hl),a			; scribble over test byte
	xor a
	out (0x30),a
	cp (hl)				; unchanged means have mdisk
	jr z, has_mdisk
	; Will become the other mode one day
	; TODO: report error here on console
	di
	halt	

has_mdisk:
	; Now how big - can be 256, 512, 768, or 1MB
	; Note: they number 1-8 and 1-4 in the docs so the nomenclature
	; is a bit strange as it's not zero based
	ld a,0x0A		; block 3 of bank 2
	out (0x30),a
	ld (hl),a
	ld a,0x12		; block 3 of bank 3
	out (0x30),a
	ld (hl),a
	ld a,0x1A		; block 3 of bank 4
	out (0x30),a
	ld (hl),a

	; Ok now see what we have
	ld b,1			; we have at least 1 bank
	ld a,0x0A
	out (0x30),a
	cp (hl)
	jr nz, counted
	inc b
	ld a,0x12
	out (0x30),a
	cp (hl)
	jr nz, counted
	inc b
	ld a,0x1A
	out (0x30),a
	cp (hl)
	jr nz, counted
	inc b

counted: ; B 256K banks
	xor a
	out (0x30),a
	; HL was 0
	ld h,b				; number of 256K banks
	ld (_ramsize), hl		; record it
	ld de,64
	or a
	sbc hl,de			; take off kernel size
	ld (_procmem), hl		; rest is user

	; Set the CTC vector
	xor a
	out (CTC_CH0),a
	; CTC 2 runs at 4MHz off the system clock
	; Set up channel 2
	; counter mode, rising edge, load constant, reset, control
	; divide by 256. Our input clock is 250Khz
	ld a,0x17
	out (CTC_CH2),a
	ld a,125
	out (CTC_CH2),a
	; Chain into channel 3
	; 
	ld a,0xD7
	out (CTC_CH3),a
	ld a,100			; 20Hz
	out (CTC_CH3),a
	; Set for 20Hz polling
	ld hl, im2_vectors
	ld de, 0xFD00			; Vector page (hard coded for now)
	ld bc,32
	ldir				; Vectors installed
	ld b,96				; Other 96 vectors
	ex de,hl
	ld de,invalid_irq		; Fill page with invalid_irq
vecset:
	ld (hl),e
	inc hl
	ld (hl),d
	inc hl
	djnz vecset
	ld a,0xFD
	ld i,a
	im 2
	ret	

dart_setup:
	.byte 0x00
	.byte 0x18		; Reset
	.byte 0x04
	.byte 0x44		; x16 (9600 baud) 8N1
	.byte 0x01
	.byte 0x1F		; interrupts for IM2
	.byte 0x03
	.byte 0xC1		; 8 bits
	.byte 0x05
	.byte 0xEA		; DTR low tx enable
	.byte 0x02
dart_irqv:
	.byte 0x10		; IRQ vector (write to port B only)

;=========================================================================
; Kernel code
;=========================================================================
	.common

_plt_monitor:
	di
	halt
_plt_reboot:
	; Map in ROM
	ld a,(_m_latch)
	and 0xBF
	ld (_m_latch),a
	out (0x00),a
	rst 0			; and back to boot ROM
_plt_idle:
	halt
	ret

invalid_irq:
	push hl
	push af
	ld hl, badirq
	call outstring
	pop af
	pop hl
	reti
badirq:
	.ascii "Bad IRQ vector"
.byte 13,10,0


;=========================================================================
; Common Memory (0xC000 upwards)
;=========================================================================
	.common
;=========================================================================

_int_disabled:
	.byte 1

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

	jr map_kernel

;=========================================================================
; Memory management
;=========================================================================

; Everything hangs off a latch including disk select. Track the value
; because we need it for many things

	.export _m_latch
_m_latch:
	.byte	0x40		; TODO check value: needs to start ROM off
page:
	.byte	0x00		; Contents of write only bank latches
savedpage:
	.byte	0x00		; Old state of bank latches for interrupts

;
;	Latch management
;
;	H = mask L = bits
;
	.export _set_latch

_set_latch:
	pop	de
	pop	hl
	push	hl
	push	de
	di
	ld	a,(_m_latch)
	and	h
	or	l
	ld	(_m_latch),a
	out	(0),a
	ld	a,(_int_disabled)
	or	a
	ret	nz
	ei
	ret

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
; map_proc_always - map process pages
; Inputs: page table address in 2     
; Outputs: none; all registers preserved
;=========================================================================

; FIXME: IRQ safety ??

map_proc_always:
map_proc_always_di:
	push	af
	ld	a,(_udata + 2     )
	ld	(page),a
	out 	(0x30),a
	pop	af
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
	push	af
	xor	a
	ld	(page),a
	out	(0x30),a
	pop	af
	ret

;=========================================================================
; map_for_swap - map a page into a bank for swap I/O
; Inputs: A = page
; Outputs: none
;
; The caller will later map_kernel to restore normality
;
;=========================================================================
map_proc_a:
map_for_swap:
	ld	(page),a
	out	(0x30),a
	ret

;=========================================================================
; map_restore - restore a saved page mapping
; Inputs: none
; Outputs: none, all registers preserved
;=========================================================================
map_restore:
	push	af
	ld	a,(savedpage)
	ld	(page),a
	out	(0x30),a
	pop	af
	ret

;=========================================================================
; map_save - save the current page mapping to map_savearea
; Inputs: none
; Outputs: none
;=========================================================================
map_save_kernel:
	push	af
	ld	a,(page)
	ld	(savedpage),a
	xor	a
	ld	(page),a
	out	(0x30),a
	pop	af
	ret

;
;	A little SIO helper
;
	.export _dart_otir

_dart_otir:
	ld b,0x06
	ld c,l
	ld hl,_dart_r
	otir
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
        out (DARTA_C), a
	in a,(DARTA_C)		; read Line Status Register
	and 0x04			; get THRE bit
	jr z,ocloop_sio
	; now output the char to serial port
	pop af
	out (DARTA_D),a
	ret

;=========================================================================
; inchar - Wait for character on UART, return in A
; Inputs: none
; Outputs: A - received character, F destroyed
;=========================================================================
inchar:
inchar_s:
        xor a                           ; read register 0
        out (DARTA_C), a
	in a,(DARTA_C)   		; read Line Status Register
	and 0x01			; test if data is in receive buffer
	jr z,inchar_s			; no data, wait
	in a,(DARTA_D)   		; read the character from the UART
	ret
