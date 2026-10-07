#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

        .export _plt_switchout
        .export _switchin
        .export _dofork
	.export _ramtop

	.common

	; ramtop must be in common although not used here
_ramtop:
	.word 0

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
;
; 
; This function can have no arguments or auto variables.
_plt_switchout:
	orcc #0x10		; irq off

        ; save machine state, including Y and U used by our C code
        ldd #0 ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	pshs d,u
	sts _udata + U_DATA__U_SP	; this is where the SP is restored in _switchin

        ; find another (or same) process to run, returned in X
        jsr _getproc
        jsr _switchin
        ; we should never get here
        jsr _plt_monitor

badswitchmsg:
	.ascii "_switchin: FAIL"
        .byte 13
	.byte 10
	.byte 0

newpp:
	.word 0

; new process pointer is in X
_switchin:
        orcc #0x10		; irq off
	tfr d,x
	stx newpp
	inc _inswap
	; get process table
	lda P_TAB__P_PAGE_OFFSET+1,x		; LSB of 16-bit page no

	cmpa #0
	bne not_swapped

	; Steal the interrupt stack. This means we have to keep interrupts
	; off whilst swapping but it's not clear we've got enough other
	; room!
	lds #$0100

	ldx _udata + U_DATA__U_PTAB
	ldx P_TAB__P_PAGE_OFFSET+1,x
	beq not_swapout		;	it's dead don't swap it out
	ldx _udata + U_DATA__U_PTAB
	pshs x
;;	andcc #0xef
	jsr _swapout		;	swapout(pptr)
	leas 2,s
not_swapout:
	ldd newpp
;;	andcc #0xef
	jsr _swapper		; 	fetch our process
	ldx newpp
	lda #1
	sta P_TAB__P_PAGE_OFFSET+1,x	; marked paged in
not_swapped:
;;	orcc #0x10
	dec _inswap
	; we have now new stacks so get new stack pointer before any jsr
	lds _udata + U_DATA__U_SP

	; get back kernel page so that we see process table
	jsr map_kernel

	ldx newpp
        ; check u_data->u_ptab matches what we wanted
	cmpx _udata + U_DATA__U_PTAB
        bne switchinfail

	lda #P_RUNNING
	sta P_TAB__P_STATUS_OFFSET,x

	; fix any moved page pointers
	lda P_TAB__P_PAGE_OFFSET+1,x
	sta _udata + U_DATA__U_PAGE+1

	clra
	clrb
	std _runticks

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        lds _udata + U_DATA__U_SP
        puls d,u ; return code and saved U and Y

        ; enable interrupts, if the ISR isn't already running
	lda _udata + U_DATA__U_ININTERRUPT
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

fork_proc_ptr:
	.word 0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.common
;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
_dofork:
        ; always disconnect the vehicle battery before performing maintenance
        orcc #0x10	 ; should already be the case ... belt and braces.

	; new process in X so make sure x is 0 in the child image

	std fork_proc_ptr
	clra
	clrb		; Child returns 0

        ; Save the stack pointer and critical registers (Y and U used by C).
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        pshs d,u ;  d has p->p_pid from above, the return value in the parent

        ; save kernel stack pointer -- when it comes back in for the childt we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with X (ie return code) containing the child PID.
        ; Hurray.
        sts _udata + U_DATA__U_SP

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	; Copy the parent properties into a temporary udata buffer
	jsr _tmpbuf
	pshs d		; save work buffer

	ldu #_udata
udsave:
	ldd ,u++
	std ,x++
	cmpu #_udata+U_DATA__TOTALSIZE
	bne udsave

	; TOS is the work buffer pointer already
	ldd fork_proc_ptr
	jsr _makeproc
	ldd fork_proc_ptr
	; We cheat a bit as we know makeproc won't change the stacked
	; pointers FIXME!
	jsr _swapout_new
	puls d	; clean up from both calls and the stack of the work buffer
	; free the buffer in D
	jsr _tmpfree

	; The child is now on disk, the parent is still running. This is
	; good, it reduces thrash
	ldx fork_proc_ptr
	ldd P_TAB__P_PID_OFFSET,x
	; Clean up and return
	puls d,u,pc
