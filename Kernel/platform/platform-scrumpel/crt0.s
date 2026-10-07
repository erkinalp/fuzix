# 1 "crt0.S"
	;
	;	For the Scrumpel this code assumes the kernel is at 0x00000
	;	on entry. Common and other high stuff is packed on the end
	;	of the image so if needed crt0 can adjust the other bank
	;	registers.
	;


	; 2013-12-18 William R Sowerbutts

	.z180
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

; Move down to 0xF600 to fit the monitor in
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256 bytes @ F600
Z80_TYPE                    .equ 2

OS_BANK                     .equ 0x00         ; value from include/kernel.h

; Memory layout
FIRST_RAM_BANK              .equ 0x00         ; low 512K of physical memory is RAM
Z180_IO_BASE                .equ 0x00

USE_FANCY_MONITOR           .equ 1            ; disabling this saves around approx 0.5KB
CPU_CLOCK_KHZ               .equ 16000        ; 16.000MHz * 1
TICKSPERSEC                 .equ 40           ; timer interrupt rate (Hz)
TCR_CLOCK		    .equ 20000

PROGBASE		    .equ 0x0000
PROGLOAD		    .equ 0x0100


; disabling this saves around approx 0.5KB
# 27
PPIDE_RD_LINE	.equ	0x20
PPIDE_WR_LINE	.equ	0x40
PPIDE_PPI_BUS_READ	.equ	0x90
PPIDE_PPI_BUS_WRITE	.equ	0x80

ppi_port_a	.equ	0x90
ppi_port_b	.equ	0x91
ppi_port_c	.equ	0x92
ppi_control	.equ	0x93

ppide_data	.equ	0x80
# 1 "../../cpu-z180/z180.def"
; ASCI serial ports
ASCI_CNTLA0                 .equ Z180_IO_BASE+0x00     ; ASCI control register A channel 0
ASCI_CNTLA1                 .equ Z180_IO_BASE+0x01     ; ASCI control register A channel 1
ASCI_CNTLB0                 .equ Z180_IO_BASE+0x02     ; ASCI control register B channel 0
ASCI_CNTLB1                 .equ Z180_IO_BASE+0x03     ; ASCI control register B channel 0
ASCI_STAT0                  .equ Z180_IO_BASE+0x04     ; ASCI status register    channel 0
ASCI_STAT1                  .equ Z180_IO_BASE+0x05     ; ASCI status register    channel 1
ASCI_TDR0                   .equ Z180_IO_BASE+0x06     ; ASCI transmit data reg, channel 0
ASCI_TDR1                   .equ Z180_IO_BASE+0x07     ; ASCI transmit data reg, channel 1
ASCI_RDR0                   .equ Z180_IO_BASE+0x08     ; ASCI receive data reg,  channel 0
ASCI_RDR1                   .equ Z180_IO_BASE+0x09     ; ASCI receive data reg,  channel 0
ASCI_ASEXT0                 .equ Z180_IO_BASE+0x12     ; ASCI extension register channel 0
ASCI_ASEXT1                 .equ Z180_IO_BASE+0x13     ; ASCI extension register channel 1
ASCI_ASTC0L                 .equ Z180_IO_BASE+0x1A     ; ASCI time constant register channel 0 low
ASCI_ASTC0H                 .equ Z180_IO_BASE+0x1B     ; ASCI time constant register channel 0 high
ASCI_ASTC1L                 .equ Z180_IO_BASE+0x1C     ; ASCI time constant register channel 1 low
ASCI_ASTC1H                 .equ Z180_IO_BASE+0x1D     ; ASCI time constant register channel 1 high

; Z180 MMU
MMU_CBR                     .equ Z180_IO_BASE+0x38     ; common1 base register
MMU_BBR                     .equ Z180_IO_BASE+0x39     ; bank base register
MMU_CBAR                    .equ Z180_IO_BASE+0x3A     ; common/bank area register

; Z180 DMA engine
DMA_SAR0L                   .equ Z180_IO_BASE+0x20     ; DMA source address reg, channel 0L
DMA_SAR0H                   .equ Z180_IO_BASE+0x21     ; DMA source address reg, channel 0H
DMA_SAR0B                   .equ Z180_IO_BASE+0x22     ; DMA source address reg, channel 0B
DMA_DAR0L                   .equ Z180_IO_BASE+0x23     ; DMA dest address reg,   channel 0L
DMA_DAR0H                   .equ Z180_IO_BASE+0x24     ; DMA dest address reg,   channel 0H
DMA_DAR0B                   .equ Z180_IO_BASE+0x25     ; DMA dest address reg,   channel 0B
DMA_BCR0L                   .equ Z180_IO_BASE+0x26     ; DMA byte count reg,     channel 0L
DMA_BCR0H                   .equ Z180_IO_BASE+0x27     ; DMA byte count reg,     channel 0H
DMA_MAR1L                   .equ Z180_IO_BASE+0x28     ; DMA memory address reg, channel 1L
DMA_MAR1H                   .equ Z180_IO_BASE+0x29     ; DMA memory address reg, channel 1H
DMA_MAR1B                   .equ Z180_IO_BASE+0x2A     ; DMA memory address reg, channel 1B
DMA_IAR1L                   .equ Z180_IO_BASE+0x2B     ; DMA I/O address reg,    channel 1L
DMA_IAR1H                   .equ Z180_IO_BASE+0x2C     ; DMA I/O address reg,    channel 1H
DMA_BCR1L                   .equ Z180_IO_BASE+0x2E     ; DMA byte count reg,     channel 1L
DMA_BCR1H                   .equ Z180_IO_BASE+0x2F     ; DMA byte count reg,     channel 1H
DMA_DSTAT                   .equ Z180_IO_BASE+0x30     ; DMA status register
DMA_DMODE                   .equ Z180_IO_BASE+0x31     ; DMA mode register
DMA_DCNTL                   .equ Z180_IO_BASE+0x32     ; DMA/WAIT control register

; Z180 Timer
TIME_TMDR0L                 .equ Z180_IO_BASE+0x0C     ; Timer data register,    channel 0L
TIME_TMDR0H                 .equ Z180_IO_BASE+0x0D     ; Timer data register,    channel 0H
TIME_RLDR0L                 .equ Z180_IO_BASE+0x0E     ; Timer reload register,  channel 0L
TIME_RLDR0H                 .equ Z180_IO_BASE+0x0F     ; Timer reload register,  channel 0H
TIME_TCR                    .equ Z180_IO_BASE+0x10     ; Timer control register
TIME_TMDR1L                 .equ Z180_IO_BASE+0x14     ; Timer data register,    channel 1L
TIME_TMDR1H                 .equ Z180_IO_BASE+0x15     ; Timer data register,    channel 1H
TIME_RLDR1L                 .equ Z180_IO_BASE+0x16     ; Timer reload register,  channel 1L
TIME_RLDR1H                 .equ Z180_IO_BASE+0x17     ; Timer reload register,  channel 1H
TIME_FRC                    .equ Z180_IO_BASE+0x18     ; Timer Free running counter

; CSIO
CSIO_CNTR		    .equ Z180_IO_BASE+0x0A     ; CSIO control/status register
CSIO_TRDR		    .equ Z180_IO_BASE+0x0B     ; CSIO transmit/receive data register

; Z180 Interrupts
INT_IL                      .equ Z180_IO_BASE+0x33     ; Interrupt vector low register
INT_ITC                     .equ Z180_IO_BASE+0x34     ; Interrupt vector low register

; Refresh control
MEM_RCR			    .equ Z180_IO_BASE+0x36	; Refresh control

; ESCC serial ports (Z80182)
ESCC_CTRL_A                 .equ 0xE0                   ; ESCC Channel A control register
ESCC_DATA_A                 .equ 0xE1                   ; ESCC Channel A data register
ESCC_CTRL_B                 .equ 0xE2                   ; ESCC Channel B control register
ESCC_DATA_B                 .equ 0xE3                   ; ESCC Channel B data register

PORT_A_DDR                  .equ 0xED                   ; Port A data direction register
PORT_A_DATA                 .equ 0xEE                   ; Port A data register
PORT_B_DDR                  .equ 0xE4                   ; Port B data direction register
PORT_B_DATA                 .equ 0xE5                   ; Port B data register
PORT_C_DDR                  .equ 0xDD                   ; Port C data direction register
PORT_C_DATA                 .equ 0xDE                   ; Port C data register

Z182_SYSCONFIG              .equ 0xEF                   ; System Configuration Register
Z182_RAMUBR                 .equ 0xE6                   ; RAM upper boundary register
Z182_RAMLBR                 .equ 0xE7                   ; RAM lower boundary register
Z182_ROMBR                  .equ 0xE8                   ; ROM boundary register

; Debugging
DEBUGBANK   .equ 0
DEBUGCOMMON .equ 0
# 16 "crt0.S"
        ; startup code
	.code

init:
        di
        ld	sp, kstack_top

	xor	a
	out0	(MMU_BBR),a
	out0	(MMU_CBR),a

	; For now we are loading the IHX file directly so don't
	; want to unpack stuff, but do need to sort out the initializer
	; instead

;	ld hl,#s__INITIALIZER
;	ld de,#s__INITIALIZED
;	ld bc,#l__INITIALIZER
;	ldir

;	jr skip_unpack


        ; move the common memory where it belongs    
        ld	hl, __bss
        ld	de, __common
        ld	bc, __common_size
        ldir
        ; and the discard
        ld	de, __discard
        ld	bc, __discard_size
        ldir

skip_unpack:
        ; then zero the data area
        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Configure memory map
        call	init_early

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop
