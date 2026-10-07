#include "../../cpu-z8/kernel-z8.def"
#include "kernel.def"

	.common

	.export _plt_switchout
	.export _switchin
	.export _dofork

; Do simple banking until we get it up and going nicely
;
;
; When we are called there will be nothing on the CPU stack but the
; return address which we need to save onto the C stack like a C function
; does
;

_plt_switchout:
	pop	a
	pop	b
	dec	r15
	sta	*r15
	mov	b,a
	dec	r15
	sta	*r15
	ldsp
	dec	r15
	sta	*r15
	mov	r9,a
	decd	r15
	sta	*r15
	mov	r8,a
	dec	r15
	sta	*r15
	mov	r7,a
	decd	r15
	sta	*r15
	mov	r6,a
	dec	r15
	sta	*r15
;FIXME	movd	%_udata+U_DATA__U_SP+1,r13
; sort out UDATA defines and if they are offsets all over tms7k
	mov	r15,a
	sta	*r13
	decd	r13
	mov	r14,a
	sta	*r13

	call	@map_proc_always

	;	Save stash until we figure upper bank flipping approach

	movd	%_udata+U_DATA__TOTALSIZE-1,r13
	movd	%_udata+U_DATA_STASH,r11
	clr b

l0:
	lda	*r13
	sta	*r11
	decd	r13
	decd	r11
	lda	*r13
	sta	*r11
	decd	r13
	decd	r11
	djnz	b,l0

	call	@map_kernel

	call	@_getproc
	lda	*r5
	decd	r15
	sta	*r15
	lda	*r4
	decd	r15
	sta	*r15
	call	@_switchin
	call	@_plt_monitor

switchin:
	clr	r12
	call	@__gargr2
	; r4/r5 is the process entry

	movd	r5,r13
	add 	%P_TAB__P_PAGE_OFFSET+1,r13	; big endian
	adc	%0,r12
	lda	*r13
	mov	a,b

	; TODO swap

;FIXME	movd	%_udata + U_DATA__U_PTAB+1,r13
	lda	*r13
	cmp	a,r4
	jnz	copyback
	decd	r13
	lda	*r13
	cmp	a,r5
	jz	skip_copyback
copyback:
	mov	b,a
	; Map process a
	call	@map_proc_a

	; Now block copy the udata

;FIXME	movd	%_udata + U_DATA__TOTALSIZE - 1,r13
	movd	%U_DATA_STASH + U_DATA__TOTALSIZE -1, r11
	clr	b

l1:
	lda	*r11
	sta	*r13
	decd	r11
	decd	r13
	lda	*r11
	sta	*r13
	decd	r11
	decd	r13
	djnz	b,l1

	movd	%U_DATA__U_PTAB+1,r13
	lda	*r13
	cmp	a,r4
	jnz	switchfail	
	decd	r13
	lda	*r13
	cmp	a,r5
	jnz	switchfail

skip_copyback:
	;	r4/5 has the process pointer
	mov	%P_RUNNING,a
	sta	*r5	; now running state
	movd	r5,r13
	add	%P_TAB__P_PAGE_OFFSET+1,r13
	adc	%0,r12

	; Now a is the page number
	lda	*r13

;FIXME	movd	%_udata + U_DATA__U_PAGE+1,r13
	sta	*r13
	decd	r13
	clr	a
	sta	*r13

	movd	%_runticks+1,r13
	sta	*r13
	decd	r13
	sta	*r13

;FIXME	movd	%_udata + U_DATA__U_SP+1,r13
	lda	*r13
	mov	a,r15
	decd	r13
	lda	*r13
	mov	a,r14

;FIXME	movd	%_udata + U_DATA__U_ININTERRUPT,r13
	lda	*r13
	jnz	in_isr
	eint
in_isr:
	; Need to pop the r6-r9 variables
	movd	r15,r13
	add	%6,r12
	adc	%0,r13
	; now points to end of r6-r9, sp, return block
	lda	*r13
	mov	a,r11
	decd	r13
	lda	*r13
	mov	a,r10
	decd	r13
	lda	*r13
	mov	a,b
	stsp
	decd	r13
	lda	*r13
	mov	a,r9
	decd	r13
	lda	*r13
	mov	a,r8
	decd	r13
	lda	*r13
	mov	a,r7
	decd	r13
	lda	*r13
	mov	a,r6
	
	add	%8,r15
	adc	%0,r14
	rets

switchfail:
	movd	%badswitchmsg,r13
	call	@outstring
	br	@_plt_monitor

_switchin:	; C entry point
	pop	a
	pop	b
	dec	r15
	sta	*r15
	mov	b,a
	dec	r15
	sta	*r15
	jmp	switchin

; Copy 56K between two banks - this one is a bit of a mess with the
; fixed banking setup.
;
; bank B to A

copypages:
	mov	a,r2
	movd	%0xddff,r11
next:				; needs optimizing
	movp	b,p6
	lda	*r11
;FIXME	movp	r2,p6
	sta	*r11
	decd	r11
	cmp	%1,r10
	jne	next
	movp	%0,p6		; kernel
	rets

	; TODO call/return stack stuff

_dofork:
	pop	a
	pop	b
	decd	r15
	sta	*r15
	mov	b,a
	decd	r15
	sta	*r15

	; Save the CPU stack value
	ldsp
	mov	b,a
	decd	r15
	sta	*r15

	mov	%2,r13
	call	@__gargr2	; r4/r5 is the process

	movd	r5,r13		; save pointer

	add	%P_TAB__P_PID_OFFSET+1,r13
	adc	%0,r12

	lda	*r13
	decd	r15
	sta	*r15
	decd	r13

	lda	*r13
	decd	r15
	sta	*r15
	
	mov	r9,a
	decd	r15
	sta	*r15	
	
	mov	r8,a
	decd	r15
	sta	*r15	
	
	mov	r7,a
	decd	r15
	sta	*r15	
	
	mov	r6,a
	decd	r15
	sta	*r15	
	
;FIXME	movd	%_udata + U_DATA__U_SP+1,r11
	mov	r15,a
	sta	*r11
	decd	r11
	mov	r14,a
	sta	*r11

	; Stack set up complete
	movd	r13,r11
	add	%P_TAB__P_PAGE_OFFSET+1,r11
	adc	%0,r10

	; get page number
	lda	*r11
	mov	a,b

;FIXME	movd	%_udata+U_DATA__U_PAGE+1,r11
	lda	*r11

	; Copying from bank b to bank a

	call	@copypages

	call	@map_proc_always

	; UDATA copy

	movd	%_udata+U_DATA__TOTALSIZE,r13
	movd	%U_DATA_STASH,r11
	clr	b

l2:	lda	*r13
	sta	*r11
	decd	r13
	decd	r11
	lda	*r13
	sta	*r11
	decd	r13
	decd	r11
	djnz	b,l2

	call	@map_kernel

	mov	%<_udata,a
	decd	r15
	sta	*r15
	mov	%>_udata,a
	decd	r15
	sta	*r15

	mov	r5,a
	decd	r15
	sta	*r15
	mov	r4,a
	decd	r15
	sta	*r15

	call	@_makeproc

	clr 	a
	movd	%_runticks + 1,r13
	sta	*r13
	decd	r13
	sta	*r13

	; Fix up stack and return as child
	add	%7,r15
	adc	%0,r14

	lda	*r15
	mov	r13,a
	add	%1,r15
	adc	%0,r14
	lda	*r15
	mov	r12,a
	add	%1,r15
	adc	%0,r14
	br	*r13		; to caller of dofork

	.data

	.export _need_resched

_need_resched:
	.byte	0

badswitchmsg:
	.ascii	"badswitch"
	.byte	0
