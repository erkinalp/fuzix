; 6809 copy to and from userspace
;
; This is lightly optimised for the dragon-samx8 platform
; using MMU task switching
;
; Note: our implementation of map_kernel does not modify any registers.  This
; might not be the case for all 6809 platforms, so be careful with any
; back-porting.

	; exported
	.export __ugetc
	.export __ugetw
	.export __uget

	.export __uputc
	.export __uputw
	.export __uput
	.export __uzero

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.common

; int16_t _ugetc(const uint8_t *user);
__ugetc:
	pshs cc			; save IRQ state
	orcc #0x10
	jsr map_proc_always
	tfr d,x
	ldb ,x
	jsr map_kernel
	clra
	puls cc,pc		; back and return

; uint16_t _ugetw(const uint16_t *user);
__ugetw:
	pshs cc
	orcc #0x10
	jsr map_proc_always
	tfr d,x
	ldd ,x			; NOTE: map_kernel safe for us
	jsr map_kernel
	puls cc,pc

; int _uget(const uint8_t *user, uint8_t *dst, usize_t count);
__uget:
	pshs cc,u
	orcc #0x10
	tfr d,x			; user address
	ldu 5,s			; dst address
	ldy 7,s			; count
	jsr map_proc_always	; make sure user task regs are set up
ugetl:
	sta 0xffd4		; task 0 (user)
	lda ,x+
	sta 0xffd5		; task 1 (kernel)
	sta ,u+
	leay -1,y
	bne ugetl
	jsr map_kernel		; make sure map_copy is up to date
	ldd #0
	puls cc,u,pc

; int _uputc(uint16_t value, uint8_t *user);
__uputc:
	pshs cc
	orcc #0x10
	jsr map_proc_always
	stb [3,s]
	jsr map_kernel
	ldd #0
	puls cc,pc

; int _uputw(uint16_t value, uint16_t *user);
__uputw:
	pshs cc
	orcc #0x10
	jsr map_proc_always
	std [3,s]
	jsr map_kernel
	ldd #0
	puls cc,pc

; int _uput(const uint8_t *source, uint8_t *user, usize_t count);
__uput:
	pshs cc,u
	orcc #0x10
	tfr d,x			; source
	ldu 5,s			; user address
	ldy 7,s			; count
	jsr map_proc_always	; make sure user task regs are set up
uputl:
	sta 0xffd5		; task 1 (kernel)
	lda ,x+
	sta 0xffd4		; task 0 (user)
	sta ,u+
	leay -1,y
	bne uputl
	jsr map_kernel
	ldd #0
	puls cc,u,pc

; int _uzero(uint8_t *user, usize_t count);
__uzero:
	pshs cc
	tfr d,x			; user address
	ldy 3,s			; count
	orcc #0x10
	jsr map_proc_always
	tfr y,d
	clra
	lsrb			; odd count?
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
	ldd #0
	puls cc,pc
