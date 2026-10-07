;
;	6809 copy to and from userspace
;
;	This is a bit weird. We have all kernel data and stack in
;	the kernel high bank so we end up flipping between the kernel
;	high which also contains stuff like our stack and the user
;	high which does not. We do this with interrupts off therefore. Not
;	pretty.
;

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	; exported
	.export __ugetc
	.export __ugetw
	.export __uget

	.export __uputc
	.export __uputw
	.export __uput
	.export __uzero

	; We can reach all of user from overlays

	.overlay1

__ugetc:
	pshs	cc		; save IRQ state
	tfr	d,x
	orcc	#0x10
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	ldb ,x
	lda	#KHIGH
	sta	hipage
	clra
	puls cc,pc	; back and return

__ugetw:
	pshs	cc
	tfr	d,x
	orcc	#0x10
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	ldy	,x
	lda	#KHIGH
	sta	hipage
	tfr	y,d
	puls	cc,pc

__uget:
	pshs	u,cc
	tfr	d,x
	ldu	5,s		; user address
	ldy	7,s		; count
	orcc	#0x10
ugetl:
	; TODO: can we avoid the reload here and optimize ?
	; also do words if we can 
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	ldb	,x+
	lda	#KHIGH
	sta	hipage
	stb	,u+
	leay	-1,y
	bne	ugetl
	clra
	clrb
	puls	u,cc,pc

__uputc:
	pshs cc
	orcc #0x10
	ldx 3,s
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	stb ,x
	lda	#KHIGH
	sta	hipage
	clra
	clrb
	puls cc,pc

__uputw:
	pshs cc
	orcc #0x10
	ldx 3,s
	tfr d,y
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	sty ,x
	lda	#KHIGH
	sta	hipage
	clra
	clrb
	puls cc,pc

;	X = source, user, size on stack
__uput:
	pshs	u,cc
	orcc	#0x10
	ldu	5,s		; user address
	ldy	7,s		; count
	tfr	d,x
uputl:
	ldb	,x+
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	stb ,u+
	lda	#KHIGH
	sta	hipage
	leay	-1,y
	bne	uputl
	clra
	clrb
	puls	 u,cc,pc

__uzero:
	pshs	cc
	ldy	3,s
	tfr	d,x
	orcc	#0x10
	lda	_udata + U_DATA__U_PAGE	; user high page
	sta	hipage
	tfr	y,d
	clra
	lsrb		; odd count?
	bcc	evenc
	sta	,x+
	leay	-1,y
	beq	zdone
evenc:
	clrb
uzloop:
	std	,x++
	leay	-2,y
	bne	uzloop
zdone:
	lda	#KHIGH
	sta	hipage
	clra
	clrb
	puls	cc,pc
