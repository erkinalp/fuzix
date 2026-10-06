! FUZIX M20 bootloader
! Loaded by BIOS SAV loader into <6>:0000 (user memory, safe from boot_final)
!
! Reads a kernel header from HD sector 64, then loads:
!   - text section to segment B (from header)
!   - data section to segment 2 (from header)
!
! Header format (16 bytes at sector 64):
!   +0x00: text segment  (word)
!   +0x02: text offset   (word)
!   +0x04: text sectors  (word)
!   +0x06: data segment  (word)
!   +0x08: data offset   (word)
!   +0x0A: data sectors  (word)
!   +0x0C: entry segment (word)
!   +0x0E: entry offset  (word)

	.segm
	.text
	.global	_start

HDR_SECTOR	= 64
ROM_DISK_IO	= 0x84000068

! Header buffer at <6>:0100
HDR_SEG		= 0x8600
HDR_OFF		= 0x0100

_start:
	! Set up stack in segment 2
	ld	r14, #0x8200
	ld	r15, #0xFF00

	! Read header sector from HD
	ld	r7, #0x0A00		! device=HD(10), opcode=read(0)
	ld	r8, #1			! 1 sector
	ld	r9, #HDR_SECTOR
	ld	r10, #HDR_SEG
	ld	r11, #HDR_OFF
	ld	r12, #0x8400
	ld	r13, #0x0068
	call	@rr12
	testb	rl7
	jr	nz, error

	! Parse header: load text section
	! Header is at <6>:0100
	ld	r2, #HDR_SEG
	ld	r3, #HDR_OFF

	ld	r10, rr2(#0)		! text segment
	ld	r11, rr2(#2)		! text offset
	ld	r8, rr2(#4)		! text sectors
	push	@rr14, r8		! save text_sectors for later
	ld	r9, #HDR_SECTOR+1	! text starts at sector 65
	ld	r7, #0x0A00
	ld	r12, #0x8400
	ld	r13, #0x0068
	call	@rr12
	testb	rl7
	jr	nz, error

	! Parse header: load data section
	ld	r2, #HDR_SEG
	ld	r3, #HDR_OFF

	ld	r10, rr2(#6)		! data segment
	ld	r11, rr2(#8)		! data offset
	ld	r8, rr2(#10)		! data sectors
	pop	r0, @rr14		! recover text_sectors
	ld	r9, #HDR_SECTOR+1
	add	r9, r0			! data starts after text
	ld	r7, #0x0A00
	ld	r12, #0x8400
	ld	r13, #0x0068
	call	@rr12
	testb	rl7
	jr	nz, error

	! Jump to entry point
	ld	r2, #HDR_SEG
	ld	r3, #HDR_OFF
	ld	r12, rr2(#12)		! entry segment
	ld	r13, rr2(#14)		! entry offset
	jp	@rr12

error:
	halt
