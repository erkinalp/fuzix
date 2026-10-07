; DragonDOS core routines.
;
; SPDX-License-Identifier: CC0-1.0
;
; By Ciaran Anscomb, 2025-2026.  This file is dedicated to the public
; domain (Creative Commons "CC0 1.0 Universal"), but do note that this
; dedication may not apply to accompanying files.

; Assumes single-sided 18 * 256 sectors per track.

; Provides:

; devopen
;
;   Call this first.  Configures nmi handler, resets the controller, sets
;   up for FDC operations then restores to track 0.  X register must
;   contain the LSN of the next sector to read.
;
; devclose
;
;  Call this when done.
;
; devread
;
;   Seek to next track if necessary, then read next sector.

; Uses:

; set_nmi_handler
;
;   Point NMI vector to X.

	.export devopen
	.export devclose
	.export devread

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

; DragonDOS registers

; FDC interface
reg_fdc_status		equ 0xFF40
reg_fdc_command		equ 0xFF40
reg_fdc_track		equ 0xFF41
reg_fdc_sector		equ 0xFF42
reg_fdc_data		equ 0xFF43

; DragonDOS control
reg_ddos_control	equ 0xFF48

; FDC commands
fdc_c_restore		equ 0x00
fdc_c_seek		equ 0x10
fdc_c_read_sector	equ 0x88
fdc_c_force_interrupt	equ 0xD0

; FDC seek options
fdc_c_verify_track	equ 0x04
fdc_c_step_6ms		equ 0x00
fdc_c_step_12ms		equ 0x01
fdc_c_step_20ms		equ 0x02
fdc_c_step_30ms		equ 0x03

; FDC force interrupt options
fdc_c_fi_no_intrq	equ 0x00

; FDC status bits
fdc_s_not_ready		equ 0x80
fdc_s_write_protect	equ 0x40
fdc_s_hld		equ 0x20
fdc_s_seek_error	equ 0x10
fdc_s_crc_error		equ 0x08
fdc_s_track0		equ 0x04
fdc_s_index_pulse	equ 0x02
fdc_s_busy		equ 0x01
fdc_s_rnf		equ 0x10
fdc_s_lost_data		equ 0x04
fdc_s_drq		equ 0x02
fdc_s_record_type	equ 0x20

; DragonDOS control bits
ddos_c_nmi_enable	equ 0x20
ddos_c_precomp		equ 0x10
ddos_c_density		equ 0x08
ddos_c_motor_on		equ 0x04
ddos_c_drive_mask	equ 0x03
ddos_c_single_density	equ 0x08
ddos_c_double_density	equ 0x00

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	.common

; Open device.
;
; entry: X = last sector LSN
; exit: A = status from restore command
; destroyed: b,x
devopen:
	pshs a
	; Naive LSN to track/sector conversion.  Assumes 18 sectors per
	; track, single-sided.
	clra
dol10:	cmpx #18
	blo dol20
	inca
	leax -18,x
	bra dol10
dol20:	sta ddos_track,pcr
	tfr x,d
	incb
	stb ddos_sector,pcr

	; Configure dummy NMI handler
	leax ddos_nmi_handler,pcr
	bsr set_nmi_handler

	; Base value for the DragonDOS control register
	clr ddos_control,pcr

	; DragonDOS reset controller
	lda #fdc_c_force_interrupt|fdc_c_fi_no_intrq
	sta reg_fdc_command
	lda #10
dol0:	deca
	bne dol0			; approx 56us delay
	lda reg_fdc_status

	; Setup for FDC operation
	ldb ddos_control,pcr
	orb #ddos_c_motor_on
	stb reg_ddos_control
	bsr ddos_restore
	puls a,pc

; Close device.

devclose:
	; Tidy up after FDC operation
	pshs a
	lda ddos_control,pcr
	sta reg_ddos_control
	puls a,pc

; Read next sector from device.

; entry: x = destination
; exit: x = next byte in destination
devread:
	pshs a,b
	lda ddos_track,pcr
	bsr ddos_seek
	ldd ddos_track,pcr	; A=track, B=sector
	pshs b
	incb			; next sector
	cmpb #18
	bls drl10
	inca			; next track
	ldb #1
drl10:	std ddos_track,pcr
	puls a			; A=sector
	bsr ddos_read_sector
	puls a,b,pc

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ddos_restore:
	clra			; fdc_c_restore
	bra ddos_type1

; entry: A = desired track
; exit: A = status register
; Turns on write precompensation above track 16
ddos_seek:
	sta reg_fdc_data
	cmpa #0x10
	bls dsl10
	lda ddos_control,pcr
	ora #ddos_c_precomp|ddos_c_motor_on
	sta reg_ddos_control
dsl10:	lda #fdc_c_seek|fdc_c_verify_track
	; fall through

ddos_type1:
	sta reg_fdc_command	; issue FDC command
dtl0:	lda reg_fdc_status
	bita #fdc_s_busy	; still BUSY?
	bne dtl0			; if so keep polling
	rts

; entry: A = desired sector, X = destination
; exit: A = status register, X = next byte in destination
ddos_read_sector:
	sta reg_fdc_sector
	lda #fdc_c_read_sector
	sta reg_fdc_command	; issue command
drsl10:	lda reg_fdc_status	; read status
	bita #fdc_s_drq		; DRQ set?
	beq drsl20		; if not, test BUSY
	lda reg_fdc_data	; byte ready: read data
	sta ,x+			; store data in memory
	bra drsl10
drsl20:	bita #fdc_s_busy	; BUSY set?
	bne drsl10		; if so, keep polling
	rts

; Dummy NMI handler.
ddos_nmi_handler:
	rti

; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	.commondata

; Work variables.

ddos_control:
	.byte 0
ddos_track:
	.byte 0
ddos_sector:
	.byte 0
