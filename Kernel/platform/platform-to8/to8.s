# 1 "to8.S"
	;
	; TO8/TO8D/T09+ systems
	;

	; exported
	.export map_kernel
	.export map_video
	.export map_proc_always
	.export map_save
	.export map_restore
	.export map_for_swap
        .export init_early
        .export init_hardware
        .export _program_vectors
	.export _need_resched

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore
# 1 "kernel.def"
U_DATA__TOTALSIZE           equ 0x0200        ; 256+256

VIDEO_BASE		    equ 0x0000	     ; 8K mapped in the video window
VIDEO_END		    equ 0x2000	     ; for now
VIDEO_OFF		    equ 0x00	     ; mapped at 0x00

PROGBASE                    equ 0x6400       ; programs and data start here

IOPAGE			    equ 0xE7	     ; I/O window
# 1 "../../cpu-6809/kernel09.def"
; Keep these in sync with struct u_data!!
U_DATA__U_PTAB              equ 0   ; struct p_tab*
U_DATA__U_PAGE              equ 2   ; uint16_t
U_DATA__U_PAGE2             equ 4   ; uint16_t
U_DATA__U_INSYS             equ 6   ; bool
U_DATA__U_CALLNO            equ 7   ; uint8_t
U_DATA__U_SYSCALL_SP        equ 8   ; void *
U_DATA__U_RETVAL            equ 10  ; int16_t
U_DATA__U_ERROR             equ 12  ; int16_t
U_DATA__U_SP                equ 14  ; void *
U_DATA__U_ININTERRUPT       equ 16  ; bool
U_DATA__U_CURSIG            equ 17  ; int8_t
U_DATA__U_ARGN              equ 18  ; uint16_t
U_DATA__U_ARGN1             equ 20  ; uint16_t
U_DATA__U_ARGN2             equ 22  ; uint16_t
U_DATA__U_ARGN3             equ 24  ; uint16_t
U_DATA__U_ISP               equ 26  ; void * (initial stack pointer when _exec()ing)
U_DATA__U_TOP               equ 28  ; uint16_t
U_DATA__U_BREAK             equ 30  ; uint16_t
U_DATA__U_CODEBASE          equ 32  ; uint16_t
U_DATA__U_SIGVEC            equ 34  ; table of function pointers (void *)

; Keep these in sync with struct p_tab!!
P_TAB__P_STATUS_OFFSET      equ 0
P_TAB__P_FLAGS_OFFSET	    equ 1
P_TAB__P_TTY_OFFSET         equ 2
P_TAB__P_PID_OFFSET         equ 3
P_TAB__P_PAGE_OFFSET        equ 15

P_RUNNING                   equ 1            ; value from include/kernel.h
P_READY                     equ 2            ; value from include/kernel.h

PFL_BATCH		    equ 4            ; value from include/kernel.h

OS_BANK                     equ 0            ; value from include/kernel.h

EAGAIN                      equ 11           ; value from include/kernel.h


; Keep in sync with struct blkbuf
BUFSIZE 		    equ 520
# 28 "to8.S"
	.discard
;
;	Get some video up early for debug
;
init_early:
	lda	#$03
	sta	$E7E5			; A000-DFFF is now the new video space
	clra
	clrb
	ldx	#$A000
wipe80:
	std	,x++
	cmpx	#$E000
	bne	wipe80
	lda	#$04
	sta	$E7E5			; put the kernel back
	lda	#$E0
	sta	$E7DD			; video bank 3, black border
	lda	#$2A			; 80 column video
	sta	$E7DC
	; Do something about the colour
	lda	#1
	ldx	#0
	ldy	#$00F0
	jsr	$EC00
	rts

init_hardware:
	ldd	#512			; for now - need to size properly
	std	_ramsize
	ldd	#512-40			; Kernel has 2,4 and half of 0
	std	_procmem		; will be 2,3,4 eventually
	ldd	@$CF			; system font pointer
	subd	#0x00F8			; back 256 as starts at 32 and back
	std	_fontbase		; 8 because it is upside down
	jsr	video_init		; see the video code
	ldd	#unix_syscall_entry	; Hook SWI
	std	@$2F
	rts

        .common

_plt_reboot:
	; TODO
_plt_monitor:
	orcc #0x10
	bra _plt_monitor
;
;	Be nice to monitor
;
___hard_irqrestore:		; B holds the data
	tfr b,a
	anda #0x10
	bne hard_di_2
	; fall through
___hard_ei:
	lda $6019
	ora #$20
	sta $6019
	andcc #0xef
	rts
___hard_di:
	tfr cc,b		; return the old irq state
hard_di_2:
	lda $6019
	anda #$DF
	sta $6019
	orcc #0x10
	rts

;
; COMMON MEMORY PROCEDURES FOLLOW
;

	.common

_program_vectors:
	ldx	#irqhandler
	stx	$6027		; Hook timer
	rts

map_kernel:
	pshs	d
map_kernel_1:
	; This is overkill somewhat but we do neeed to set the video bank
	; for irq cases interrupting video writes, ditto 0000-3FFF ?
	ldd	#0x0462
	std	kmap
	std	$E7E5		;	set the A000-DFFF and 0000-3FFF bank
	puls	d,pc

map_video:
	pshs	a
	lda	#0x63
	sta	kmap+1
	sta	$E7E6		;	Video in the low 16K bank
	puls	a,pc

	.commondata
kmap:
	.byte	0		; 	A000-DFFF
	.byte	0		;	0000-3FFF
savemap:
	.byte	0
	.byte	0

	.common
map_proc_always:
	pshs	a
	;	Set the upper page. The low 16K is kernel, the other chunk
	;	is fixed for now until we tackle video.
	lda	U_DATA__U_PAGE+1
	sta	kmap
	sta	$E7E5		;	Set A000-DFFF and video bank. Don't
				;	touch the 8K bank 0 map
	lda	#0x63
	sta	kmap+1
	sta	$E7E6		;	Video for user space at 0
	; TODO - map video on this switch
	puls	a,pc

map_save:
	pshs	d
	ldd	kmap
	std	savemap
	bra	map_kernel_1

map_restore:
	pshs	d
	ldd	savemap
	std	kmap
	std	$E7E5
	puls	d,pc

map_for_swap:
	; TODO
	rts


	.common
outchar:
	rts

	.common

_need_resched:
	.byte 0

;
;	Interrupt glue
;
	.common

;
;	Hook the timer interrupt but frob the stack so that we get
;	to run last by pushing a fake short rti frame
;
irqhandler:
	; for a full frame pshs cc,a,b,dp,x,y,u,pc then fix up 10,s 0,s
	; but firstly try Bill Astle's trick
	ldx	#interrupt_handler
	tfr	cc,a
	anda	#$7F
	pshs	a,x
	jmp	$E830	; will run and then end up in interrupt_handler

;
;	Keyboard glue
;
	.code

	.export _mon_keyboard
	.export _mon_mouse
	.export _mon_lightpen
;
;	This is interlocked by the IRQ paths
;
_mon_keyboard:
	jmp	$E806

;
;	These require the in_bios flag
;
_mon_mouse:
	jsr	$EC08
	beq	right_up
	lda	#2
	bra	left
right_up:
	lda	#0		; preserve C
left:
	bcc	left_up
	inca
left_up:
	; Now do position
	sta	_mouse_buttons
	jsr	$EC06
	stx	_mouse_x
	sty	_mouse_y
	rts

_mon_lightpen:
	jsr	$E818
	bcs	no_read
	stx	_mouse_x
	sty	_mouse_y
	jsr	$E81B
	lda	#0
	adca	#0
	sta	_mouse_buttons
	ldd	#1
	rts
no_read:
	ldd	#0
	rts


	.common
;
;	Floppy glue
;
;	Set in_bios so we can avoid re-entry between floppy
;	and keyboard scan
;
	.export _fdbios_flop

_fdbios_flop:
	lda	#1
	sta	_in_bios
	tst	_fd_map
	beq	via_kernel
	; Loading into a current user pages
	jsr	map_proc_always
via_kernel:
	jsr	$E82A
	ldb	#0
	bcc	flop_good
	ldb	@$4E
flop_good:
	; ensure map is correct
	clr	_in_bios
	jmp	map_kernel
