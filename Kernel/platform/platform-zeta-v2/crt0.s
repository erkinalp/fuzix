# 1 "crt0.S"
        ; exported symbols
        .export init
        .export init_from_rom
        .export _boot_from_rom
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
# 8 "crt0.S"
        ; startup code
	.code
init:                       ; must be at 0x88 -- warm boot methods enter here
        xor a
        jr init_common
init_from_rom:              ; must be at 0x8B -- bootrom.s enters here
        ld a, 1
        ; fall through
init_common:
        di
        ld (_boot_from_rom), a
        or a
        jr nz, mappedok     ; bootrom.s loads us in the correct pages

        ; move kernel to the correct location in RAM
        ; note that this cannot cope with kernel images larger than 48KB
        ld hl, 0x0000
        ld a, 32               ; first page of RAM is page 32
movenextbank:
        out (MPGSEL_3), a       ; map page at 0xC000 upwards
        ld de, 0xC000
        ld bc, 0x4000          ; copy 16KB
        ldir
        inc a
        cp 35                  ; done three pages?
        jr nz, movenextbank

	; setup the memory paging for kernel
        out (MPGSEL_3), a       ; map page 35 at 0xC000
        ld a, 32
        out (MPGSEL_0), a       ; map page 32 at 0x0000
        inc a
        out (MPGSEL_1), a       ; map page 33 at 0x4000
        inc a
        out (MPGSEL_2), a       ; map page 34 at 0x8000

mappedok:
        ; switch to stack in high memory
        ld sp, kstack_top

        ; move the common memory where it belongs    
        ld hl, __bss
        ld de, __common
        ld bc, __common_size
        ldir
        ; and the discard (which might overlap)
        ld de, __discard
        ld bc, __discard_size-1
	add hl,bc
	ex de,hl
	add hl,bc
	ex de,hl
        lddr
	ldd
        ; then zero the data area
        ld hl, __bss
        ld de, __bss + 1
        ld bc, __bss_size - 1
        ld (hl), 0
        ldir

        ; Hardware setup
        call init_hardware

        ; Call the C main routine
        call _fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr stop

_boot_from_rom: .byte 0
