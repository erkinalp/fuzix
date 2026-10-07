# 1 "usermem.S"
;
;	6809 copy to and from userspace
;
;	TODO: optimise - our layout should be such that all kernel
;	copy to/from user areas are mapped when user is mapped
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
# 11 "usermem.S"
	; exported
	.export __ugetc
	.export __ugetw
	.export __uget

	.export __uputc
	.export __uputw
	.export __uput
	.export __uzero

	.common

__ugetc:
	pshs cc		; save IRQ state
	orcc #0x10
	tfr d,x
	jsr map_proc_always
	ldb ,x
	jsr map_kernel
	clra
	tfr d,x
	puls cc,pc	; back and return

__ugetw:
	pshs cc
	orcc #0x10
	tfr d,x
	jsr map_proc_always
	ldx ,x
	jsr map_kernel
	puls cc,pc

__uget:
	pshs u,cc
	tfr d,x
	ldu 5,s		; user address
	ldy 7,s		; count
	orcc #0x10
ugetl:
	jsr map_proc_always
	lda ,x+
	jsr map_kernel
	sta ,u+
	leay -1,y
	bne ugetl
	ldx #0
	puls u,cc,pc

__uputc:
	pshs cc
	orcc #0x10
	tfr d,x
	ldd 3,s
	jsr map_proc_always
	exg d,x
	stb ,x
	jsr map_kernel
	ldx #0
	puls cc,pc

__uputw:
	pshs cc
	orcc #0x10
	tfr d,x
	ldd 3,s
	jsr map_proc_always
	exg d,x
	std ,x
	jsr map_kernel
	ldx #0
	puls cc,pc

;	X = source, user, size on stack
__uput:
	pshs u,cc
	orcc #0x10
	tfr d,x
	ldu 5,s		; user address
	ldy 7,s		; count
uputl:
	lda ,x+
	jsr map_proc_always
	sta ,u+
	jsr map_kernel
	leay -1,y
	bne uputl
	ldx #0
	puls u,cc,pc

__uzero:
	pshs cc
	tfr d,x
	ldy 3,s
	orcc #0x10
	jsr map_proc_always
	tfr y,d
	clra
	lsrb		; odd count?
	bcc evenc
	sta ,x+
	leay -1,y
	beq zdone
evenc:
	clrb
uzloop:
	std ,x++
	leay -2,y
	bne uzloop
zdone:
	jsr map_kernel
	ldx #0
	puls cc,pc
