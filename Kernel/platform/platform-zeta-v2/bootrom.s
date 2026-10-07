# 1 "bootrom.S"
;
;	ROM boot for FUZIX on the ZETA SBC V2
;
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
# 6 "bootrom.S"
		.abs
		.org 0x0000
start:
		; map ROM page 0 to bank 0 and enable paging
		di			; better be safe than sorry
		xor a
		out (MPGSEL_0),a	; map page 0 (ROM) to bank 0
		ld a,1
		out (MPGENA),a		; enable paging

		; copy FUZIX kernel to RAM
		; 4 pages, starting from ROM page 0, RAM page 32
		xor a
kernel_copy:
		out (MPGSEL_1),a	; map ROM page to bank 1
		add a,32		; RAM page = ROM page + 32	
		out (MPGSEL_2),a	; map RAM page to bank 2
		ld hl,0x4000		; source - bank 1 offset
		ld de,0x8000		; destination - bank 2 offset
		ld bc,0x4000		; count - 16 KiB
		ldir			; copy it
		sub 31			; next ROM page = RAM page - 32 + 1
		cp 4			; are we there yet (ROM page == 4?)
		jr nz,kernel_copy

;; 		; copy data to RAM disk
;; 		; 16 pages, starting from ROM page 4, RAM page 48
;; 		ld a,4
;; ramdisk_copy:
;; 		out (MPGSEL_1),a	; map ROM page to bank 1
;; 		add 44			; RAM page = ROM page + 44
;; 		out (MPGSEL_2),a	; map RAM page to bank 2
;; 		ld hl,0x4000		; source - bank 1 offset
;; 		ld de,0x8000		; destination - bank 2 offset
;; 		ld bc,0x4000		; count - 16 KiB
;; 		ldir			; copy it
;; 		sub 43			; next ROM page = RAM page - 44 + 1
;; 		cp 20			; are we there yet (RAM page == 4 + 16?)
;; 		jr nz,ramdisk_copy
;; 
		; scary... switching memory bank under our feet
		ld a,32		; map page 32 (RAM) to bank 0 
		out (MPGSEL_0),a
		inc a			; map page 33 (RAM+16k) to bank 1
		out (MPGSEL_1),a
		inc a			; map page 34 (RAM+32K) to bank 2
		out (MPGSEL_2),a
		inc a			; map page 35 (RAM+48K) to bank 3
		out (MPGSEL_3),a

		jp 0x8B                 ; jump to init_from_rom in crt0

		.org 0x87
		nop			; pad
