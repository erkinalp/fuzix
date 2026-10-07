# 1 "devrd_zeta2_hw.S"
        ; exported symbols
        .export _rd_page_copy
        .export _rd_cpy_count
        .export _rd_reverse
        .export _rd_dst_userspace
        .export _rd_dst_address
        .export _rd_src_address
        .export _devmem_read
        .export _devmem_write
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
 
# 14 "devrd_zeta2_hw.S"
	.code

_devmem_write:
        ld a, 1
        ld (_rd_reverse), a             ; 1 = write
        jr _devmem_go
_devmem_read:
        xor a
        ld (_rd_reverse), a             ; 0 = read
        inc a
_devmem_go:
        ld (_rd_dst_userspace), a       ; 1 = userspace
        ; load the other parameters
        ld hl, (_udata + 98    )
        ld (_rd_dst_address), hl
        ld hl, (_udata + 102   )
        ld (_rd_src_address), hl
        ld hl, (_udata + 102   +2)
        ld (_rd_src_address+2), hl
        ld hl, (_udata + 100   )
        ld (_rd_cpy_count), hl
        ; for single byte transfers we can optimise away the outer loop
        dec l                           ; test for HL=1
        ld a, h
        or l
        jp nz, _rd_plt_copy        ; > 1 byte, do it the hard way
        call _rd_page_copy              ; transfer single byte
        ld hl, 1                       ; return with HL set appropriately
        ret

	.common

;=========================================================================
; _rd_page_copy - Copy data from one physical page to another
; See notes in devrd.h for input parameters
;=========================================================================
_rd_page_copy:
        ; split rd_src_address into page and offset -- it's limited to 20 bits (max 0xFFFFF)
        ; example address 0x000ABCDE 
        ; in memory it is stored: DE BC 0A 00
        ; offset would be 0x0ABCDE & 0x3FFF = 0x3CDE
        ; page would be   0x0ABCDE >> 14    = 0x2A

        ; compute source page number
        ld a,(_rd_src_address+1)        ; load 0xBC -> B
        ld b, a
        ld a,(_rd_src_address+2)        ; load 0x0A -> A
        rl b                            ; grab the top bit into carry
        rla                             ; shift accumulator left, load carry bit at the bottom 
        rl b                            ; and again
        rla                             ; now A is the page number (0x2A)

        ; map source page
        ld (mpgsel_cache+1),a           ; save the mapping
        out (MPGSEL_1),a                ; map source page to bank 1

        ; compute source page offset, store in DE
        ld a,(_rd_src_address+1)
        and 0x3F                       ; mask to 16KB
        or 0x40                        ; add offset for bank 1
        ld d, a
        ld a,(_rd_src_address+0)
        ld e, a                         ; now offset is in DE

        ; compute destination page index (addr 0xABCD >> 14 = 0x02)
        ld a,(_rd_dst_address+1)        ; load top 8 bits
        and 0xc0                       ; mask off top 2 bits
        rlca                            ; rotate into lower 2 bits
        rlca
        ld b, 0
        ld c, a                         ; store in l

        ; look up page number
        ld a,(_rd_dst_userspace)        ; are we loading into userspace memory?
        or a
        jr nz, rd_translate_userspace
        ld hl, _kernel_pages           ; get kernel page table
        jr rd_do_translate
rd_translate_userspace:
        ld hl, _udata + 2               ; get user process page table
rd_do_translate:
        add hl, bc                      ; add index to base ptr (uint8_t *)
        ld a, (hl)                      ; load the page number from the page table

        ; map destination page
        ld (mpgsel_cache+2),a           ; save the mapping
        out (MPGSEL_2),a                ; map destination page to bank 2

        ; compute destination page offset, store in HL
        ld a,(_rd_dst_address+1)
        and 0x3F                       ; mask to 16KB
        or 0x80                        ; add offset for bank 2
        ld h, a
        ld a, (_rd_dst_address+0)
        ld l, a                         ; now offset is in HL

        ; load byte count
        ld bc,(_rd_cpy_count)           ; bytes to copy

        ; check if reversed
        ld a, (_rd_reverse)
        or a
        jr nz, go
        ex de,hl                        ; reverse if necessary
go:
        ldir                            ; do the copy
        jp map_kernel                   ; map back the kernel

; variables
_rd_cpy_count:
        .word   0                       ; uint16_t
_rd_reverse:
        .byte   0                       ; bool
_rd_dst_userspace:
        .byte   0                       ; bool
_rd_dst_address:
        .word   0                       ; uint16_t
_rd_src_address:
        .byte   0                       ; uint32_t
        .byte   0
        .byte   0
        .byte   0
;=========================================================================
