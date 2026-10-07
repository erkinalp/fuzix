	.export __syscall
	.export __syscallva

	.code

__syscall:
	jsr head
sysexit:
	cmpx #0			; X holds errno, if any
	beq noerr1
	stx _errno		; D is -1 in this case
noerr1:
	rts

__syscallva:
	jsr head + 3
	bra sysexit
