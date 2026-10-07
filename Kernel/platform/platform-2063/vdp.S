#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.common

; TMS setup
VDP_IRQ		.equ	0
VDP_DIRECT	.equ	1
VDP_ROP		.equ	1

;
;	We need 2us between the last control write and a data read. We might
;	be running at 10MHz or faster so use long delays
;
;	These will only work on the TMS9918A text mode but fail on the
;	later chips. There is no 9938/58 for the 2063 however
;
;	word 0x0018 is 1800 or JR relative 0. 12 clocks 2bytes
;
#define VDP_DELAY	.word 0x0018
#define VDP_DELAY2	.word 0x0018
; The 2063 doesn't waitstate the I/O so back to back outs go funny
#define VDP_DELAY3	nop

#define VDP_DIRECT
#define VDP_ROP

#include "../../dev/vdp1u.S"
