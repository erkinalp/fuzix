# 1 "ds1302-n8vem.S"
; 2015-02-19 Sergey Kiselev
; 2014-12-31 William R Sowerbutts
; N8VEM SBC / Zeta SBC DS1302 real time clock interface code
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256@F000
Z80_TYPE		.equ	0	; just an old good Z80
USE_FANCY_MONITOR	.equ	1	; disabling this saves around approx 0.5KB

PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Zeta SBC V2 mnemonics for I/O ports etc

CONSOLE_RATE		.equ	38400

CPU_CLOCK_KHZ		.equ	20000

; Z80 CTC ports
CTC_CH0		.equ	0x20	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x21	; CTC channel 1 (periodic interrupts)
CTC_CH2		.equ	0x22	; CTC channel 2 (UART interrupt)
CTC_CH3		.equ	0x23	; CTC channel 3 (PPI interrupt)

; 37C65 FDC ports
FDC_CCR		.equ	0x28	; Configuration Control Register (W/O)
FDC_MSR		.equ	0x30	; 8272 Main Status Register (R/O)
FDC_DATA	.equ	0x31	; 8272 Data Port (R/W)
FDC_DOR		.equ	0x38	; Digital Output Register (W/O)
FDC_TC		.equ	0x38	; Pulse terminal count (R/O)

; 8255 PPI ports
PPI_BASE	.equ	0x60
PPI_PORTA	.equ 	PPI_BASE + 0	; Port A
PPI_PORTB	.equ 	PPI_BASE + 1	; Port B
PPI_PORTC	.equ 	PPI_BASE + 2	; Port C
PPI_CONTROL 	.equ 	PPI_BASE + 3	; PPI Control Port

; 16550 UART
UART0_BASE	.equ	0x68
UART0_RBR	.equ	UART0_BASE + 0	; DLAB=0: Receiver buffer register (R/O)
UART0_THR	.equ	UART0_BASE + 0	; DLAB=0: Transmitter holding reg (W/O)
UART0_IER	.equ	UART0_BASE + 1	; DLAB=0: Interrupt enable register
UART0_IIR	.equ	UART0_BASE + 2	; Interrupt identification reg (R/0)
UART0_FCR	.equ	UART0_BASE + 2	; FIFO control register (W/O)
UART0_LCR	.equ	UART0_BASE + 3	; Line control register
UART0_MCR	.equ	UART0_BASE + 4	; Modem control register
UART0_LSR	.equ	UART0_BASE + 5	; Line status register
UART0_MSR	.equ	UART0_BASE + 6	; Modem status register
UART0_SCR	.equ	UART0_BASE + 7	; Scratch register 
UART0_DLL	.equ	UART0_BASE + 0	; DLAB=1: Divisor latch - low byte
UART0_DLH	.equ	UART0_BASE + 1	; DLAB=1: Divisor latch - high byte

; DS1302 RTC
N8VEM_RTC	.equ	0x70	; RTC / bit banging (R/W)

; MMU Ports
MPGSEL_0	.equ	0x78	; Bank_0 page select register (W/O)
MPGSEL_1	.equ	0x79	; Bank_1 page select register (W/O)
MPGSEL_2	.equ	0x7A	; Bank_2 page select register (W/O)
MPGSEL_3	.equ	0x7B	; Bank_3 page select register (W/O)
MPGENA		.equ	0x7C	; memory paging enable register, bit 0 (W/O)

Z80_MMU_HOOKS		    .equ 0

;
;	Values for the PPI port
;
ppi_port_a	.equ	0x60
ppi_port_b	.equ	0x61
ppi_port_c	.equ	0x62
ppi_control	.equ	0x63

PPIDE_CS0_LINE	.equ	0x08
PPIDE_CS1_LINE	.equ	0x10
PPIDE_WR_LINE	.equ	0x20
PPIDE_RD_LINE	.equ	0x40
PPIDE_RST_LINE	.equ	0x80

PPIDE_PPI_BUS_READ	.equ	0x92
PPIDE_PPI_BUS_WRITE	.equ	0x80

ppide_data	.equ	PPIDE_CS0_LINE
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 8 "ds1302-n8vem.S"
; -----------------------------------------------------------------------------
; DS1302 interface
; -----------------------------------------------------------------------------

N8VEM_RTC       .equ 0x70
# 22
	.data

_rtc_shadow:    .byte 0           ; we can't read back the latch contents, so we must keep a copy
_rtc_port:	.word N8VEM_RTC	  ; port to use

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
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256@F000
Z80_TYPE		.equ	0	; just an old good Z80
USE_FANCY_MONITOR	.equ	1	; disabling this saves around approx 0.5KB

PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Zeta SBC V2 mnemonics for I/O ports etc

CONSOLE_RATE		.equ	38400

CPU_CLOCK_KHZ		.equ	20000

; Z80 CTC ports
CTC_CH0		.equ	0x20	; CTC channel 0 and interrupt vector
CTC_CH1		.equ	0x21	; CTC channel 1 (periodic interrupts)
CTC_CH2		.equ	0x22	; CTC channel 2 (UART interrupt)
CTC_CH3		.equ	0x23	; CTC channel 3 (PPI interrupt)

; 37C65 FDC ports
FDC_CCR		.equ	0x28	; Configuration Control Register (W/O)
FDC_MSR		.equ	0x30	; 8272 Main Status Register (R/O)
FDC_DATA	.equ	0x31	; 8272 Data Port (R/W)
FDC_DOR		.equ	0x38	; Digital Output Register (W/O)
FDC_TC		.equ	0x38	; Pulse terminal count (R/O)

; 8255 PPI ports
PPI_BASE	.equ	0x60
PPI_PORTA	.equ 	PPI_BASE + 0	; Port A
PPI_PORTB	.equ 	PPI_BASE + 1	; Port B
PPI_PORTC	.equ 	PPI_BASE + 2	; Port C
PPI_CONTROL 	.equ 	PPI_BASE + 3	; PPI Control Port

; 16550 UART
UART0_BASE	.equ	0x68
UART0_RBR	.equ	UART0_BASE + 0	; DLAB=0: Receiver buffer register (R/O)
UART0_THR	.equ	UART0_BASE + 0	; DLAB=0: Transmitter holding reg (W/O)
UART0_IER	.equ	UART0_BASE + 1	; DLAB=0: Interrupt enable register
UART0_IIR	.equ	UART0_BASE + 2	; Interrupt identification reg (R/0)
UART0_FCR	.equ	UART0_BASE + 2	; FIFO control register (W/O)
UART0_LCR	.equ	UART0_BASE + 3	; Line control register
UART0_MCR	.equ	UART0_BASE + 4	; Modem control register
UART0_LSR	.equ	UART0_BASE + 5	; Line status register
UART0_MSR	.equ	UART0_BASE + 6	; Modem status register
UART0_SCR	.equ	UART0_BASE + 7	; Scratch register 
UART0_DLL	.equ	UART0_BASE + 0	; DLAB=1: Divisor latch - low byte
UART0_DLH	.equ	UART0_BASE + 1	; DLAB=1: Divisor latch - high byte

; DS1302 RTC
N8VEM_RTC	.equ	0x70	; RTC / bit banging (R/W)

; MMU Ports
MPGSEL_0	.equ	0x78	; Bank_0 page select register (W/O)
MPGSEL_1	.equ	0x79	; Bank_1 page select register (W/O)
MPGSEL_2	.equ	0x7A	; Bank_2 page select register (W/O)
MPGSEL_3	.equ	0x7B	; Bank_3 page select register (W/O)
MPGENA		.equ	0x7C	; memory paging enable register, bit 0 (W/O)

Z80_MMU_HOOKS		    .equ 0

;
;	Values for the PPI port
;
ppi_port_a	.equ	0x60
ppi_port_b	.equ	0x61
ppi_port_c	.equ	0x62
ppi_control	.equ	0x63

PPIDE_CS0_LINE	.equ	0x08
PPIDE_CS1_LINE	.equ	0x10
PPIDE_WR_LINE	.equ	0x20
PPIDE_RD_LINE	.equ	0x40
PPIDE_RST_LINE	.equ	0x80

PPIDE_PPI_BUS_READ	.equ	0x92
PPIDE_PPI_BUS_WRITE	.equ	0x80

ppide_data	.equ	PPIDE_CS0_LINE
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
