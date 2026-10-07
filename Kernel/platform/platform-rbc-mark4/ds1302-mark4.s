# 1 "ds1302-mark4.S"
	.code
# 1 "../../dev/ds1302_commonu.s"
; 2015-02-19 Sergey Kiselev
; 2014-12-31 William R Sowerbutts
; N8VEM SBC / Zeta SBC / RC2014 DS1302 real time clock interface code
;
;
        ; exported symbols
        .export _ds1302_set_ce
        .export _ds1302_set_clk
        .export _ds1302_set_data
        .export _ds1302_set_driven
        .export _ds1302_get_data
# 1 "../../dev/../build/kernelu.def"
; UZI mnemonics for memory addresses etc

; Move down to 0xF600 to fit the monitor in
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256 bytes @ F800
Z80_TYPE                    .equ 2

OS_BANK                     .equ 0x00         ; value from include/kernel.h

; N8VEM Mark IV mnemonics
FIRST_RAM_BANK              .equ 0x80         ; low 512K of physical memory is ROM/ECB window.
Z180_IO_BASE                .equ 0x40
MARK4_IO_BASE               .equ 0x80

; No standard clock speed for the Mark IV board, but this is a common choice.
CPU_CLOCK_KHZ               .equ 36864        ; 18.432MHz * 2
TICKSPERSEC                 .equ 40           ; timer interrupt rate (Hz)
TCR_CLOCK		    .equ 23040

PROGBASE		    .equ 0x0000
PROGLOAD		    .equ 0x0100


; disabling this saves around approx 0.5KB
# 1 "../../dev/../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 16 "../../dev/ds1302_commonu.s"
; -----------------------------------------------------------------------------
; DS1302 interface
; -----------------------------------------------------------------------------

_ds1302_get_data:
	push bc
	ld bc,(_rtc_port)
        in a, (c)       	; read input register
        and 0x01         ; mask off data pin
        ld l, a                 ; return result in L
	pop bc
        ret

_ds1302_set_driven:
	pop de
	pop hl
	push hl
	push de
	push bc
        ld a, (_rtc_shadow)
        and >0xDF20       ; 0 - output pin
        bit 0, l                ; test bit
        jr nz, writereg
        or <0xDF20 
        jr writereg

_ds1302_set_data:
	pop de
	pop hl
	push hl
	push de
	push bc
        ld bc, 0x7F80 
        jr setpin

_ds1302_set_ce:
	pop de
	pop hl
	push hl
	push de
	push bc
        ld bc, 0xEF10 
        jr setpin

_ds1302_set_clk:
	pop de
	pop hl
	push hl
	push de
	push bc
        ld bc, 0xBF40 
        jr setpin

setpin:
        ld a, (_rtc_shadow)     ; load current register contents
        and b                   ; unset the pin
        bit 0, l                ; test bit
        jr z, writereg          ; arg is false
        or c                    ; arg is true
writereg:
	ld bc, (_rtc_port)
        out (c), a	        ; write out new register contents
        ld (_rtc_shadow), a      ; update our shadow copy
	pop bc
        ret
