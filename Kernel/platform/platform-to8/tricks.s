# 1 "tricks.S"
;
;	Bank switching for Thompson TO8 and TO9+
;
;
;	TODO: parent first mode would be a win due to the copier cost
;	TODO: assumes TO8/TO9+ mode
;
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
# 11 "tricks.S"
	.export _plt_switchout
	.export _switchin
	.export _dofork
	.export _ramtop

	.commondata

	; ramtop must be in common although not used here
_ramtop:
	.word 0

newpp:   .word 0

_cur6:
	.byte 0

	.common

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
;
_plt_switchout:
	orcc #0x10		; irq off

        ; save machine state, including Y and U used by our C code
        ldd #0 ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	pshs d,u
	sts U_DATA__U_SP	; this is where the SP is restored in _switchin

	; get process table in
	jsr map_kernel

        ; find another (or same) process to run, returned in D
        jsr _getproc
        jsr _switchin
        ; we should never get here
        jsr _plt_monitor

badswitchmsg: .ascii "_switchin: FAIL"
.byte 13
	.byte 10
	.byte 0


; new process pointer is in X
_switchin:
        orcc #0x10		; irq off

	stx newpp
	; get process table
	lda P_TAB__P_PAGE_OFFSET+1,x		; Page of process we are switching in as

	; check if we are switching to the same process
	cmpa U_DATA__U_PAGE+1
	beq no_work

	; process was swapped out?
	cmpa #0
	bne not_swapped
	jsr _swapper		; void swapper(ptptr p)
	ldx newpp

not_swapped:
	lda U_DATA__U_PAGE+1
	cmpa #0xFF		; Exited so no mapping ?
	bne keep_map
	clr _cur6		; Don't try and save old map to page FF
keep_map:
	; This isn't quite as simple as usual. We've got two blocks of memory
	; and one of them we have to copy in and out of
	; TODO: spot _exit() case where we don't need to save anything.
	ldb _cur6		; current bank 6xxx
	beq bankclear		; image in the space may be dead

bankout:
	incb			; Get the mapping for the save page
	stb $E7E5		; set bank for A000-DFFF (assumes TO8 mapping)
	pshs x,y
	ldx #$6100		; copy all but the monitor vars (includes udata)
	ldy #$A100
bankout_cp:
	ldd ,x++
	std ,y++
	cmpx #$A000		; copy the entire bank out
	bne bankout_cp
	puls x,y

bankclear:
	; Now it gets trickier. We are copying in - but over our live stack!
	; IRQ and FIRQ must be off ! FIXME- FIRQ mask above...
bankin:
	lda P_TAB__P_PAGE_OFFSET+1,x
	sta _cur6		; remember the bank that is actually now resident
	inca			; Get the page for the copy
	sta $E7E5		; map it at A000-DFFF for copying
	ldx #$A100
	ldy #$6100
bankin_cp:
	ldd ,x++
	std ,y++
	cmpx #$E000
	bne bankin_cp

no_work:
	ldx newpp
	lda P_TAB__P_PAGE_OFFSET+1,x
	; Put upper map back correctly
	sta $E7E5
	lds U_DATA__U_SP
	; Ok now in the right spot on the child stack and mapping

	; get back kernel page so that we see process table
	jsr map_kernel

	ldx newpp
        ; check u_data->u_ptab matches what we wanted
	cmpx U_DATA__U_PTAB
        bne switchinfail

	lda #P_RUNNING
	sta P_TAB__P_STATUS_OFFSET,x

	; fix any moved page pointers
	lda P_TAB__P_PAGE_OFFSET+1,x
	sta U_DATA__U_PAGE+1

	ldx #0
	stx _runticks

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        lds U_DATA__U_SP
        puls d,u ; return code and saved U

        ; enable interrupts, if the ISR isn't already running
	lda U_DATA__U_ININTERRUPT
        bne swtchdone ; in ISR, leave interrupts off
	andcc #0xef
swtchdone:
        rts

switchinfail:
	jsr outx
        ldx #badswitchmsg
        jsr outstring
	; something went wrong and we didn't switch in what we asked for
        jmp _plt_monitor

	.data

fork_proc_ptr: .word 0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.common
;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
_dofork:
        ; always disconnect the vehicle battery before performing maintenance
        orcc #0x10	 ; should already be the case ... belt and braces.

	; new process in X, get parent pid into D

	stx fork_proc_ptr
	ldd P_TAB__P_PID_OFFSET,x

        ; Save the stack pointer and critical registers (Y and U used by C).
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        pshs d,u ;  x has p->p_pid from above, the return value in the parent

        ; save kernel stack pointer -- when it comes back in the parent we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with X (ie return code) containing the child PID.
        ; Hurray.
        sts U_DATA__U_SP

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	jsr fork_copy			; copy process memory to new bank
					; and save parents uarea

	; We are now in the kernel child context

        ; now the copy operation is complete we can get rid of the stuff
        ; _switchin will be expecting from our copy of the stack.
	puls d

	ldd #_udata
	pshs d
        ldd fork_proc_ptr
        jsr _makeproc
	puls x

	; any calls to map process will now map the childs memory

        ; in the child process, fork() returns zero.
	clra
	clrb
        ; runticks = 0;
	std _runticks
	;
	; And we exit, with the kernel mapped, the child now being deemed
	; to be the live uarea. The parent is frozen in time and space as
	; if it had done a switchout().
	puls u,pc

fork_copy:
; Unoptimized - we don't look at U_BREAK and other stuff
;
	ldx fork_proc_ptr
	ldb P_TAB__P_PAGE_OFFSET+1,x	; child page
	stb _cur6			; child is now deemed to own cur6
	ldb U_DATA__U_PAGE+1		; parent bank
	incb				; parent low page
	stb $E7E5			; make it appear at A000

	; Copy the low page into the backup for the parent
	ldx #$6100
	ldy #$A100
save_low:				; copy the low 16K of user
	ldd ,x++			; stack etc into the parent
	std ,y++			; copy
	cmpx #$A000
	bne save_low

	; we are in common so we can steal 0000-3FFF *if we are careful* -
	; review the IRQ handlers! TODO. This won't work on a TO9 as we'll
	; only be able to land ROM pages there
	; Weirdness: the two 8K blocks are flipped from the 0000 view so
	; copy accordingly to compensate.
	ldb _cur6
	stb $E7E5			; map the child properly into A000-DFFF
	ldb U_DATA__U_PAGE+1
	orb #$60			; RAM in wndow, writeable
	stb $E7E6			; map the low 16K to the parent upper block

	; Copy the high page into the child copy allowing for the 8K flip
	ldx #$2000
	ldy #$A000
save_hi:				; copy the low 16K of user
	ldd ,x++			; stack etc into the parent
	std ,y++			; copy
	cmpx #$4000
	bne save_hi

	ldx #0
save_hi2:				; copy the low 16K of user
	ldd ,x++			; stack etc into the parent
	std ,y++			; copy
	cmpx #$2000
	bne save_hi2
	
	jmp map_kernel			; put the memory map back sane
