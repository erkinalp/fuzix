; setjmp / longjmp for 6809 FUZIX
; Copyright 2015 Tormod Volden

	; exported
	.export _setjmp
	.code

; int setjmp(jmp_buf)
_setjmp:
	tfr d,x
	ldd ,s		; return address
	sty ,x++
	stu ,x++
	sts ,x++
	std ,x
	ldd #0
	rts
