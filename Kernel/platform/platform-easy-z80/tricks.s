# 1 "tricks.S"
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes @ D000
Z80_TYPE		.equ	0	; just a old good Z80
USE_FANCY_MONITOR	.equ	1	; disabling this saves around approx 0.5KB

Z80_MMU_HOOKS		.equ 0



PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Mnemonics for I/O ports etc

CONSOLE_RATE		.equ	115200

CPU_CLOCK_KHZ		.equ	10000

; Z80 CTC ports
CTC_CH0		.equ	0x88	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x89	; CTC channel 1 (periodic interrupts)
CTC_CH2		.equ	0x8A	; CTC channel 2
CTC_CH3		.equ	0x8B	; CTC channel 3

; 37C65 FDC ports
FDC_CCR		.equ	0x48	; Configuration Control Register (W/O)
FDC_MSR		.equ	0x50	; 8272 Main Status Register (R/O)
FDC_DATA	.equ	0x51	; 8272 Data Port (R/W)
FDC_DOR		.equ	0x58	; Digital Output Register (W/O)
FDC_TC		.equ	0x58	; Pulse terminal count (R/O)

; MMU Ports
MPGSEL_0	.equ	0x78	; Bank_0 page select register (W/O)
MPGSEL_1	.equ	0x79	; Bank_1 page select register (W/O)
MPGSEL_2	.equ	0x7A	; Bank_2 page select register (W/O)
MPGSEL_3	.equ	0x7B	; Bank_3 page select register (W/O)
MPGENA		.equ	0x7C	; memory paging enable register, bit 0 (W/O)
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 4 "tricks.S"
TOP_PORT	.equ	MPGSEL_3
# 1 "../../lib/z80ubank16.S"
; Based on code 2013-12-21 William R Sowerbutts

;
;	This is intended to provide generic support for most 16K multibank
;	platforms.
;
;	The platform should define
;	TOP_PORT		the I/O port that the top page byte is
;				written into
;
;	top_bank must resolve to the byte used to store the top bank value
;	in memory
;
;	If the platform needs to maniuplate the page byte values then this
;	code will need to be copied and tweaked, for now anyway.
;
;	fork_copy remains platform specific.
;

        .export _plt_switchout
        .export _switchin
        .export _dofork
	.export _ramtop
	.export _need_resched

	.common

; ramtop must be in common for single process swapping cases
; and its a constant for the others from before init forks so it'll be fine
; here
_ramtop:
	.word 0
_need_resched:
	.byte 0

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
_plt_switchout:
        ; save machine state

        ld hl, 0 ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; _udata + 14     with the following on the stack:
        push hl ; return code
        push ix
        push iy
        ld (_udata + 14    ), sp ; this is where the SP is restored in _switchin

        ; find another process to run (may select this one again)
        call _getproc

        push hl
        call _switchin

        ; we should never get here
        call _plt_monitor

badswitchmsg: .ascii "_switchin: FAIL"
.byte 13, 10, 0

_switchin:
        di
        pop bc  ; return address
        pop de  ; new process pointer
;
;	FIXME: do we actually *need* to restore the stack !
;
        push de ; restore stack
        push bc ; restore stack

        ld hl, 15 +3	; Common
	add hl, de		; process ptr
	ld a, (hl)
	ld (top_bank),a
	out (TOP_PORT), a	; *CAUTION* our stack just left the building

	; ------- No stack -------
        ; check u_data->u_ptab matches what we wanted
        ld hl, (_udata + 0     ) ; u_data->u_ptab
        or a                    ; clear carry flag
        sbc hl, de              ; subtract, result will be zero if DE==IX
        jr nz, switchinfail

	; wants optimising up a bit
	ld hl, 0 
	add hl, de
	ld (hl), 1           

        ; runticks = 0
        ld hl, 0
        ld (_runticks), hl

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        ld sp, (_udata + 14    )

	; ---- New task stack ----

        pop iy
        pop ix
        pop hl ; return code

        ; enable interrupts, if the ISR isn't already running
        ld a, (_udata + 16    )
	ld (_int_disabled),a
        or a
        ret nz ; in ISR, leave interrupts off
        ei
        ret ; return with interrupts on

switchinfail:
	call outhl
        ld hl, badswitchmsg
        call outstring
	; something went wrong and we didn't switch in what we asked for
        jp _plt_monitor

fork_proc_ptr: .word 0 ; (C type is struct p_tab *) -- address of child process p_tab entry

;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
_dofork:
        ; always disconnect the vehicle battery before performing maintenance
        di ; should already be the case ... belt and braces.

        pop de  ; return address
        pop hl  ; new process p_tab*
        push hl
        push de

        ld (fork_proc_ptr), hl

        ; prepare return value in parent process -- HL = p->p_pid;
        ld de, 3 
        add hl, de
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a

        ; Save the stack pointer and critical registers.
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        push hl ; HL still has p->p_pid from above, the return value in the parent
        push ix
        push iy

        ; save kernel stack pointer -- when it comes back in the parent we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with HL (ie return code) containing the child PID.
        ; Hurray.
        ld (_udata + 14    ), sp

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	; --------- we switch stack copies in this call -----------
	call fork_copy			; copy 0x000 to udata.u_top and the
					; uarea and return on the childs
					; common
	; We are now in the kernel child context

        ; now the copy operation is complete we can get rid of the stuff
        ; _switchin will be expecting from our copy of the stack.
        pop bc
        pop bc
        pop bc

        ; The child makes its own new process table entry, etc.
	ld hl, _udata
	push hl
        ld hl, (fork_proc_ptr)
        push hl
        call _makeproc
        pop bc 
	pop bc

	; any calls to map process will now map the childs memory

        ; runticks = 0;
        ld hl, 0
        ld (_runticks), hl
        ; in the child process, fork() returns zero.
	;
	; And we exit, with the kernel mapped, the child now being deemed
	; to be the live uarea. The parent is frozen in time and space as
	; if it had done a switchout().
        ret
# 8 "tricks.S"
	.common

fork_copy:
	ld hl, (_udata + 28    )
	ld de, 0x0fff
	add hl, de		; + 0x1000 (-1 for the rounding to follow)
	ld a, h
	rlca
	rlca			; get just the number of banks in the bottom
				; bits
	and 3
	inc a			; and round up to the next bank
	ld b, a
	; we need to copy the relevant chunks
	ld hl, (fork_proc_ptr)
	ld de, 15 
	add hl, de
	; hl now points into the child pages
	ld de, _udata + 2     
	; and de is the parent
fork_next:
	ld a,(hl)
	out (MPGSEL_1), a	; 0x4000 map the child
	ld c, a
	inc hl
	ld a, (de)
	out (MPGSEL_2), a	; 0x8000 maps the parent
	inc de
	exx
	ld hl, 0x8000		; copy the bank
	ld de, 0x4000
	ld bc, 0x4000		; we copy the whole bank, we could optimise
				; further
	ldir
	exx
	call map_kernel		; put the maps back so we can look in p_tab
	djnz fork_next
	ld a, c
	ld (mpgsel_cache+3),a	; cache the page number
	out (MPGSEL_3), a	; our last bank repeats up to common
	; --- we are now on the stack copy, parent stack is locked away ---
	ret			; this stack is copied so safe to return on

	
