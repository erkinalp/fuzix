# 1 "crt0.S"
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes @ 0xC000
U_DATA_STASH		.equ	0x7E00	; 512 bytes at top of pageable
Z80_TYPE		.equ	0	; CMOS

Z80_MMU_HOOKS		.equ 0

CONFIG_SWAP		.equ 1

PROGBASE		.equ	0x0000
PROGLOAD		.equ	0x0100

; Mnemonics for I/O ports etc

CONSOLE_RATE		.equ	9600

CPU_CLOCK_KHZ		.equ	4000

B_RST	.equ	0x80
B_AACK	.equ	0x10
B_ASEL	.equ	0x04
B_ABUS	.equ	0x01

B_BUSY	.equ	0x40
B_MSG	.equ	0x10
B_CD	.equ	0x08
B_IO	.equ	0x04

B_PHAS	.equ	0x08

ncr_base	.equ	0x20
ncr_data	.equ	ncr_base
ncr_cmd		.equ	ncr_base + 1
ncr_mod		.equ	ncr_base + 2
ncr_tgt		.equ	ncr_base + 3
ncr_bus		.equ	ncr_base + 4
ncr_st		.equ	ncr_base + 5
ncr_dma_w	.equ	ncr_base + 5
ncr_int		.equ	ncr_base + 7
ncr_dma_r	.equ	ncr_base + 7
ncr_dack	.equ	ncr_base + 8
DARTA_D		.equ	0x80
DARTA_C		.equ	0x84
DARTB_D		.equ	0x88
DARTB_C		.equ	0x8C

CTC_CH0		.equ	0x40
CTC_CH1		.equ	0x50
CTC_CH2		.equ	0x60
CTC_CH3		.equ	0x70
# 4 "crt0.S"
	.code

; Starts at 0x0100
; We are mapped with bank 1 page 1 low and bank 1 page 2 high (fixed)
; Or on a non MDISK system with the 64K RAM low/high
;
; We were loaded as a packed image from 0000 up. The loader
; in FE00-FFFF gets replaced with the serial buffers once we take
; control if the loader is used.
;
; This works as a raw disk load or a CP/M app
;
        di

	ld	sp,kstack_top

	; Discard is packed over the BSS to keep the image smaller
	; for loading
	ld	hl, __bss
        ld	de, __discard
        ld	bc, __discard_size
        ldir

        ; Zero the data area
        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop

	.discard
	.export im2_vectors
;
;	Make sure common memory starts with the im2 vectors
;
im2_vectors:
	; First 16 vectors
	.word	0
	.word	0
	.word	0
	.word	interrupt_handler	; CTC 3 vector
	.word	0
	.word	0
	.word	0
	.word	0
	.word	siob_txd
	.word	siob_status
	.word	siob_rx_ring
	.word	siob_special
	.word	sioa_txd
	.word	sioa_status
	.word	sioa_rx_ring
	.word	sioa_special
