; fzload09 - Fuzix loader for Dragon and CoCo
;
; SPDX-FileCopyrightText: Copyright 2025-2026 Ciaran Anscomb
; SPDX-License-Identifier: GPL-2.0-or-later

; BOOT will load 16 sectors of data (LSNs 2--17) from 0x2600+.  The first
; part of the payload can follow the loader code.  From then on, we read
; a sector (256 bytes) at a time from LSN 18+ using the configured driver.
;
; The payload is a 64K raw binary starting starting at address 0.  In
; order to populate a whole 64K map, we first ensure our loader is running
; outside the first four pages (relocate to 0x8000-0xBFFF).  Then for each
; 16K chunk, we map the appropriate page to 0x4000-0x7FFF and copy data
; into the mapped area.
;
; We then use the area immediately below COMMON to hold a small trampoline
; that finishes initialising the memory map and JMPs to address 0, where
; we expect the kernel to do something useful.
;
; Link with ONE data driver (fzload-raw or fzload-dzip).
;
; Link with ONE block device driver (fzload-dragondos or fzload-cocosdc).

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Dragon: BOOT will have loaded 16 sectors, continue from LSN 18.
btrk_nsecs	equ 16
next_lsn	equ 18

reloc_size	equ 256*btrk_nsecs

; Fuzix will use a 4K COMMON on the SAMx8, meaning it starts at 0xF000.
common_start	equ 0xF000

; Once memory is mapped properly, this is where we start Fuzix.
fuzix_exec	equ 0x0000

; Screen addresses while loading
con_top		equ 0x8000
con_end		equ 0x8200

	.export set_nmi_handler
	.export error

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; First stage.  This is executed by BOOT (or DOS).

	.code

	.ascii "OS"	; BOOT magic
	
	orcc #0x50	; mask interrupts
	lda #0xFF
	tfr a,dp
	;setdp 0xFF
	clr 0x0071	; cold boot on reset
	sta @0xFFDF	; 64K mode

	; video base address = 0x10000
	ldd #0x0800	; 0x10000 / 32
	std @0xFF38
	; ensure area 2 is the same in tasks 0 and 1 (page 4),
	; as that's where we're going to run
	lsra		; A = 4
	sta @0xFF32
	sta @0xFF36

	ldd #reloc_size
	subd #sector_buf
	addd #__code
	std buf_nbytes	; not relocated yet, absolute is fine

	; relocate rest of loader to 0x8200+ as page 4
	; note: reloc_size is actually a bit generous (as it includes this
	; code here), but it doesn't hurt
	ldx #__common
	ldu #0x8200
s1cl0:	lda ,x+
	sta ,u+
	cmpu #0x8200+reloc_size
	blo s1cl0
	; jump to newly-relocated loader...
	jmp 0x8200

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Second stage.  Copied to 0x8200+ as page 4 by the first stage.  This now
; reads in the DECB data and positions it within pages 0--3, mapping to
; 0x4000--0x7FFF as a work area.

	.common

	lds #0xC000

	leax sector_buf,pcr
	stx buf_ptr,pcr
	ldx #next_lsn
	bsr devopen

	sta @0xFFD5	; task 1

	bsr con_cls
	leax msg_loading,pcr
	bsr con_strout

	; read in raw data stream
read_loop:
	clra
	bsr read_16k
	lda #1
	bsr read_16k
	lda #2
	bsr read_16k
	lda #3
	bsr read_16k
	bra exec_kernel

; Various messages

	.literal

msg_loading:
	.byte 0x0C,0x0F,0x01,0x04
	.byte 0x09,0x0E,0x07,0x20
	.byte 0x06,0x15,0x1A,0x09
	.byte 0x18,0x00			; fci /LOADING FUZIX/,0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	.commondata

con_crs_timer:
	.byte 0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; If no bytes left in buffer, read the next few sectors.  Returns next
; byte in buffer in B.

	.common

	.export read_word
	.export read_byte

read_word:
	bsr read_byte
	tfr b,a
	; fall through
read_byte:
	pshs x
	ldx buf_nbytes,pcr
	bne fetch_byte
	; read next 9 LSNs (half a track)
	leax sector_buf,pcr
	stx buf_ptr,pcr
	pshs a
	lda #9
rbl0:	bsr devread
	deca
	bne rbl0
	; x = x - sector_buf (hoop-jumping pic version)
	tfr x,d
	subd buf_ptr,pcr
	tfr d,x
	puls a
fetch_byte:
	leax -1,x
	stx buf_nbytes,pcr
	ldx buf_ptr,pcr
	ldb ,x+
	stx buf_ptr,pcr
	tstb
	puls x,pc

	.commondata

; Buffer handling
buf_ptr:
	.word 0x0000	; initialised to sector_buf
buf_nbytes:
	.word 0x0000	; initialised to reloc_size-sector_buf

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; EXEC
;
; - Closes the boot device
; - Sets up areas 0, 1 & 3 in both tasks (we're running from 2)
; - Copies a trampoline into the discard are just below COMMON
; - JMPs to it
;
; The trampoline:
;
; - Sets up area 2 in both tasks (we're now running from 3)
; - JMPs to 0

	.common

exec_kernel:
	bsr devclose
	clra
	tfr a,dp
	;setdp 0x00

	ldb #1		; A still = 0
	std 0xFF30	; init task 0 areas 0 & 1
	std 0xFF34	; init task 1 areas 0 & 1
	ldb #3
	stb 0xFF33	; init task 0 area 3
	stb 0xFF37	; init task 1 area 3

	; we sneak our trampoline in right before the COMMON
	; area at 0xF000, assuming it'll be unused
 	ldu #common_start-sizeof_trampoline
	leay trampoline,pcr
	ldx #sizeof_trampoline
exec0:	lda ,y+
	sta ,u+
	leax -1,x
	bne exec0
	jmp common_start-sizeof_trampoline

trampoline:
	lda #2
	sta 0xFF32	; init task 0 area 2
	sta 0xFF36	; init task 1 area 2
	jmp @fuzix_exec
sizeof_trampoline	equ 10

	;setdp 0xFF

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Just enough console functionality to print messages and animate a
; spinning cursor.

	.common

	.export con_crs_tick
	.export con_anim_crs
	.export con_chrout

; decrement timer and animate cursor
con_crs_tick:
	dec con_crs_timer,pcr
	beq con_anim_crs
	rts
; animate cursor
con_anim_crs:
	pshs a,x
	inc con_crs_idx,pcr
	lda con_crs_idx,pcr
	anda #3
	leax con_crs,pcr
	lda a,x
	sta [con_pos,pcr]
	puls a,x,pc

; print error and halt
error:	bsr con_strout
cal0:	bra cal0

; print string
; entry: x = string
; exit: x = byte after nul-terminator
con_strout:
	pshs a
csl10:	lda ,x+
	beq csl20
	bsr con_chrout
	bra csl10
csl20:	puls a,pc

; print character
; destroyed: a (possibly)
con_chrout:
	pshs x
	ldx con_pos,pcr
	cmpa #0x0A
	beq ccl10
	sta ,x+
	bra ccl20
	; newline
ccl10:	bsr con_clr_eol_x
ccl20:	cmpx #con_end
	bhs ccl30
	stx con_pos,pcr
	puls x,pc
; scroll up
; destroyed: a
con_scrup:
	pshs x
ccl30:	ldx #con_top
ccl40:	lda 32,x
	sta ,x+
	cmpx #con_end-32
	blo ccl40
	stx con_pos,pcr
	bsr con_clr_eol_x
	puls x,pc

; clear to end of line
; exit: X = byte after current line
; destroyed: a
con_clr_eol:
	ldx con_pos,pcr
	; fall through
; entry: X = con_pos
con_clr_eol_x:
	pshs b
cel0:	lda #0x20
	sta ,x+
	tfr x,d
	bitb #0x1F
	bne cel0
	puls b,pc

; clear screen
; destroyed: a
con_cls:
	pshs x
	ldx #con_top
	stx con_pos,pcr
	lda #0x20
clsl0:	sta ,x+
	cmpx #con_end
	blo clsl0
	puls x,pc

	.literal

; Animated cursor: / - \ !
con_crs:
	.byte 0x2F,0x2D,0x1C,0x21

	.commondata

; Console variables
con_pos:
	.word 0x8000
con_crs_idx:
	.byte 0

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Miscellaneous

	.common

set_nmi_handler:
	pshs a
	stx 0x010A
	lda #0x7E
	sta 0x0109
	puls a,pc

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; Although it wastes a bit of space, it's nice if the kernel ends up
; sector-aligned in the disk image.
;	align 256,0

	.discard

sector_buf:
