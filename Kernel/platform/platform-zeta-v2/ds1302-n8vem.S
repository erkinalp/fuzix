; 2015-02-19 Sergey Kiselev
; 2014-12-31 William R Sowerbutts
; N8VEM SBC / Zeta SBC DS1302 real time clock interface code

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; DS1302 interface
; -----------------------------------------------------------------------------

N8VEM_RTC       .equ 0x70

#define PIN_CE		0xEF10
#define PIN_DATA_HIZ	0xDF20
#define PIN_CLK		0xBF40
#define PIN_DATA_OUT	0x7F80
#define PIN_DATA_IN	0x01
#define PIN_OTHER	0x00


	.data

_rtc_shadow:    .byte 0           ; we can't read back the latch contents, so we must keep a copy
_rtc_port:	.word N8VEM_RTC	  ; port to use

	.code

#include "../../dev/ds1302_commonu.s"
