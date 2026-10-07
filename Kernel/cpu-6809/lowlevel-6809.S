;
;	Common elements of low level interrupt and other handling. We
; collect this here to minimise the amount of platform specific gloop
; involved in a port
;
;	Based upon code (C) 2013 William R Sowerbutts
;

	; debugging aids
	.export outcharhex
	.export outd
	.export outx
	.export outy
	.export outnewline
	.export outstring
	.export outstringhex
	.export outnibble

        ; exported symbols
        .export unix_syscall_entry
	.export null_handler
	.export dispatch_process_signal
        .export _doexec
        .export trap_illegal
	.export nmi_handler
	.export interrupt_handler
	.export _sys_cpu
	.export _sys_cpu_feat
	.export _sys_stubs
	.export _set_cpu_type

#include "../build/kernel.def"
#include "kernel09.def"

        .common

;
;	The vararg syscalls end up with a slightly different calling
;	sequence
;		arg4
;		arg3
;		arg2
;		arg1
;		return addr (to syscall C function)
;		return addr (to syscall handler)
;		B = syscall no
;
unix_va_syscall:
	pshs dp,cc,u
	ldu	#_udata + U_DATA__U_ARGN
	stb	_udata + U_DATA__U_CALLNO
	leax	8,s
	ldd	,x++
	std	,u++
	bra	syscall
;
;
; entry point for Fuzix system calls. Called via JSR. On entry we are on the
; user stack and our stack looks like this
;		arg4
;		arg3
;		arg2
;		return addr (to syscall C function)
;		return addr (to syscall handler)
;		X = syscall number, D = arg1
;
unix_syscall_entry:
	pshs dp,cc,u
        orcc #0x10
	ldu #_udata + U_DATA__U_ARGN
	std ,u++
	tfr x,d
	stb _udata + U_DATA__U_CALLNO
	leax 8,s	; skip return addresses
syscall:
	ldd ,x++	; second argument from caller's stack
	std ,u++
	ldd ,x++ 	; third
	std ,u++
	ldd ,x++ 	; fourth
	std ,u++
        ; save process stack pointer (in user page)
        sts _udata + U_DATA__U_SYSCALL_SP
        ; switch to kernel stack (makes our stack valid again)
        lds #kstack_top

	; we are in syscall state
	lda #1
	sta _udata + U_DATA__U_INSYS

        ; map in kernel keeping common
	jsr map_kernel

        ; re-enable interrupts
        andcc #0xef

	lda #>_udata
	tfr a,dp
        ; now pass control to C
        jsr _unix_syscall

        orcc #0x10
	; let the interrupt logic know we are not in kernel mode any more
	clr _udata + U_DATA__U_INSYS

        ; map process memory back in based on common (common may have
        ; changed on a task switch)
        jsr map_proc_always

        ; switch back to user stack
        lds _udata + U_DATA__U_SYSCALL_SP

	; stack is now valid but user stack
        ; check for signals, call the handlers
        jsr dispatch_process_signal

        ; check if error condition to be signalled on return
        ldx _udata + U_DATA__U_ERROR
	beq not_error
	ldd #-1
        ; error code in d, result in x
        bra unix_return

not_error:
        ; no error to signal! return syscall return value instead of error code
        ldd _udata + U_DATA__U_RETVAL
unix_return:
	puls dp,cc,u,pc
;
;	We must rts on the right bank !
;
dispatch_process_signal:
        ; check if any signal outstanding
        ldb _udata + U_DATA__U_CURSIG
        beq dosigrts

	; The signal handler is entitled to make syscalls which will
	; in turn trash these two
	ldx _udata + U_DATA__U_RETVAL
	ldy _udata + U_DATA__U_ERROR
	pshs x,y
        ; put number in X as the argument for the signal handler
	; so extend it to 16bit
	clra
	tfr d,x

	lslb		;	2 bytes per entry
        ; load the address of signal handler function
	ldy #_udata + U_DATA__U_SIGVEC
	leay b,y
	ldu ,y		; now u = udata.u_sigvec[cursig]

        ; udata.u_cursig = 0;
	clr _udata + U_DATA__U_CURSIG

        ; restore signal handler to the default.
        ; udata.u_sigvec[cursig] = SIG_DFL;
        ; SIG_DFL = 0
	clr ,y+
	clr ,y

        andcc #0xef
	jsr ,u

signal_return:
	lda #>_udata
	tfr a,dp
        orcc #0x10
	puls x,y
	stx _udata + U_DATA__U_RETVAL
	sty _udata + U_DATA__U_ERROR
dosigrts:
        rts

_doexec:
	; d is the jump address
	tfr d,x
	;
        orcc #0x10
	; this is a funny extra path out of syscall so we must also cover
	; the exit from kernel here

	; map task into address space
	; preserves x
        jsr map_proc_always

	; base address
	ldy _udata + U_DATA__U_CODEBASE
        ; u_data.u_insys = false
        clr _udata + U_DATA__U_INSYS
	; At this point the stack goes invalid
        lds _udata + U_DATA__U_ISP
	andcc #0xef			; IRQs on
        jmp ,x

;
;	Very simple IRQ handler, we get interrupts and we may have to
;	poll ttys from it. The more logic we could move to common here the
;	better.
;


;
;	Called when interrupts have been re-enabled within the timer
;	interrupt. We hand it to the platform re-interrupt handler. If
;	none is expected then it can panic, or if the platform is clever
;	it can do the needed work.
;
reinterrupt:
	jsr _plt_reinterrupt
	; Signals and other magic will happen when the first level of
	; interrupt handling returns
	rti

interrupt_handler:
	lda #>_udata
	tfr a,dp
	; If the platform interrupt code re-enabled interrupts then
	; we are on the interrupt stack already and platform author
	; is assumed to know what they are doing 8)
	tst _udata + U_DATA__U_ININTERRUPT
	bne reinterrupt

	; Do not use the stack before the switch...
	; FIXME: add profil support here (need to keep profil ptrs
	; unbanked if so ?)

	lda #1
        sta _udata + U_DATA__U_ININTERRUPT

        ; switch stacks
        sts istack_switched_sp
        lds #istack_top

	jsr map_save

	ldb _udata + U_DATA__U_INSYS	; In a system call ?
	bne in_kernel

        ; we're not in kernel mode, check for signals and fault
	lda #0x7e
	cmpa 0		; JMP at 0?
	beq nofault	; yes?  not a fault
	sta 0		; fault - put JMP back
	jsr map_kernel
	ldb #11		; SIGSEGV
	jsr trap_signal	; signal the user with a fault

nofault:
in_kernel:
        jsr map_kernel

	;
	; If the kernel decides to task switch it will set
	; _need_resched, and will only do so if the caller was in
	; user space so has a free kernel stack

        jsr _plt_interrupt

        ldx istack_switched_sp	; stack back
        clr _udata + U_DATA__U_ININTERRUPT
        lda _udata + U_DATA__U_INSYS
        bne intret_x
	lda _need_resched
	beq no_switch

	clr _need_resched
	stx _udata + U_DATA__U_SYSCALL_SP	; save again somewhere safe for
					; preemption
	; Pre emption occurs on the task stack. Conceptually its a
	; not quite a syscall
	lds #kstack_top
	jsr _chksigs		; check signal state
	;
	ldx _udata + U_DATA__U_PTAB
	; Move to ready state
	lda P_TAB__P_STATUS_OFFSET,x
	cmpa #P_RUNNING
	bne not_running
	lda #P_READY
	sta P_TAB__P_STATUS_OFFSET,x
not_running:
	; Sleep on the kernel stack, IRQs will get re-enabled if need
	; be
	jsr _plt_switchout
	;
	; We will resume here after the pre-emption. Get back onto
	; the user stack and map ourself in
	jsr map_proc_always
	lds _udata + U_DATA__U_SYSCALL_SP
	bra intdone

	    ; Not task switching - the easy and usual path
no_switch:
	; On a return from an interrupt restore the old mapping as it
	; will vary during kernel activity and we need to put it put
	; it back as it was before the interrupt
	; pre-emption is handled differently...
	jsr map_restore
	lds istack_switched_sp

intdone:
        ; we're not in kernel mode, check for signals
	; runs off the user stack
	pshs y
        jsr dispatch_process_signal
	puls y

intret:
        rti
	;	From kernel
	;	Restore the user mapping then
	;	switch to the user stack ptr
intret_x:
	jsr map_restore
	tfr x,s
	bra intret

;  Enter with B being the signal to send ourself
trap_signal:
	pshs b
	ldd _udata + U_DATA__U_PTAB	;  ssig(pid, B)
	jsr _ssig
	puls b,pc

;  Called from process context (hopefully)
null_handler:
	; kernel jump to NULL is bad
	lda _udata + U_DATA__U_INSYS
	bne trap_illegal
	lda #>_udata
	tfr a,dp
	; user is merely not good
	ldd #9			; SIGKILL
	pshs d
	ldd _udata + U_DATA__U_PTAB
	ldx #39			; Function 39 = kill
	jsr unix_syscall_entry	; kill (getpid(), SIGKILL)
	leas 2,s
	ldx #0
	jsr unix_syscall_entry
	; Fall into trap handler if this impossibly returns
trap_illegal:
	ldx #illegalmsg
	jsr outstring
	jsr _plt_monitor

illegalmsg: .ascii "[trap_illegal]"
        .byte 13,10,0


dpsmsg:	.ascii "[dispsig]"
        .byte 13,10,0


nmimsg: .ascii "[NMI]"
        .byte 13,10,0

nmi_handler:
	lds #istack_top		; We aren't coming back so this is ok
	jsr map_kernel
        ldx #nmimsg
	jsr outstring
        jsr _plt_monitor

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	CPU type management
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;
;	Stubs starts with a jump for syscall entry and a second jump
;	for vararg syscall entry (subtly different stack layout). Two entry
;	points is cheap enough. Avoid SWI and SWI2 as they are used on some
;	platforms by ROM firmware we can't get rid off
;
_sys_stubs:
	jmp unix_syscall_entry
	jmp unix_va_syscall

	.commondata

_sys_cpu:
	.byte 4
_sys_cpu_feat:
	.byte 0

	.common
;
;	Check for a 6309 (as per The 6309 Book)
;
_set_cpu_type:
	pshs d
	.word 0x1043
	cmpb 1,s
	puls d
	beq is8
	lda #1
	sta _sys_cpu_feat
is8:
	rts


; outstring: Print the string at X until 0 byte is found
; destroys: A, X
outstring:
	lda ,x+
	beq outstrdone
        jsr outchar
        bra outstring
outstrdone:
	rts

; print the string at (X) in hex (continues until 0 byte seen)
outstringhex:
	lda ,x+
	beq outstrdone
        jsr outcharhex
	lda #32
	jsr outchar
        bra outstringhex

; output a newline
outnewline:
        lda #0x0d  ; output newline
        jsr outchar
        lda #0x0a
        jsr outchar
        rts

outx:  ; prints X
	pshs d
	tfr x,d
	bsr outd
	puls d,pc

outy:  ; prints Y
	pshs d
	tfr y,d
	bsr outd
	puls d,pc

outd:  ; prints D in hex.
	pshs b
	bsr outcharhex
	puls a
	; FALL THROUGH

; print the byte in A as a two-character hex value
outcharhex:
	pshs a
        lsra
        lsra
        lsra
        lsra
        bsr outnibble
	puls a
	; FALL THROUGH

; print the nibble in the low four bits of A
outnibble:
        anda #0x0f ; mask off low four bits
        cmpa #9
        ble num    ; less than 10?
        adda #0x07 ; start at 'A' (10+7+0x30=0x41='A')
num:    adda #0x30 ; start at '0' (0x30='0')
        jsr outchar
        rts


	.code

; Compiler helpers

	.export _swab

_swab:	exg	a,b
	rts

	.export _memset

_memset:
	pshs	u,d		; d is the address
	tfr	d,u
	ldx	8,s		; count
	beq	nowork
	ldb	7,s		; byte
msl:	stb	,u+
	leax	-1,x
	bne	msl
nowork:
	puls	d,u,pc

	.export _memcpy

_memcpy:
	pshs	u,d
	tfr	d,u		; dest
	ldx	6,s		; src
	ldy	8,s		; count
	beq	nowork
mcl:	lda	,x+
	sta	,u+
	leay	-1,y
	bne	mcl
	puls	d,u,pc

	.export _strlen

_strlen:
	tfr	d,x
	ldd	#0xFFFF
next:
	addd	#1
	tst	,x+
	bne	next
	rts
