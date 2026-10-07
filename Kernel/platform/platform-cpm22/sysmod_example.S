		.abs
		.org BASE

		.export _sysmod
_sysmod:

		.export _sysmod_init
		.export _sysmod_irq_handler
		.export _sysmod_nmi_handler
		.export _sysmod_set_map
		.export _sysmod_info
		.export _sysmod_conost
		.export _sysmod_auxist
		.export _sysmod_auxost
		.export _sysmod_idle
		.export _sysmod_rtc_secs
		.export _sysmod_monitor
		.export _sysmod_reboot
		.export _sysmod_conconf
		.export _sysmod_auxconf
		.export _sysmod_joystick

_sysmod_base:
_sysmod_init:
		jp sysmod_init
_sysmod_info:
		jp sysmod_info
_sysmod_set_map:
		jp sysmod_set_map
_sysmod_irq_handler:
		jp sysmod_irq_handler
_sysmod_nmi_handler:
		jp sysmod_nmi_handler
_sysmod_conost:
		jp sysmod_conost
_sysmod_auxist:
		jp sysmod_auxist
_sysmod_auxost:
		jp sysmod_auxost
_sysmod_idle:
		jp sysmod_idle
_sysmod_rtc_secs:
		jp sysmod_rtc_secs
_sysmod_monitor:
		jp sysmod_monitor
_sysmod_reboot:
		jp sysmod_reboot
_sysmod_conconf:
		jp sysmod_conconf
_sysmod_auxconf:
		jp sysmod_auxconf
_sysmod_joystick:
		jp sysmod_joystick

sysmod_init:
		im 1
		ld a,1
		out (27),a		; timer on
		ret

sysmod_irq_handler:
		ld a,0xC3
		ld (0x38),a
		ld (0x39),hl
sysmod_idle:
		ret
sysmod_nmi_handler:
		ld a,0xC3
		ld (0x66),a
		ld (0x67),hl
		ret
sysmod_set_map:
		out (21),a		; set the page to A, 0 = kernel
		ret			; ie default CP/M TPA
sysmod_info:
		ld hl,sysinfo
		ret
sysmod_rtc_secs:
		xor a
		out (25),a		; RTC register for seconds
		in a,(26)		; Seconds in BCD
		ld h,a
		and 15
		ld l,a			; BCD low bits
		ld a,h
		rra
		rra
		rra
		rra
		and 15
		add a,a			; high x 2
		ld h,a
		add a,a			; high x 4
		add a,a			; high x 8
		add a,h			; high x 10
		or l			; now decimal
		ld l,a
		ret
;
;	I/O routines we would like that are missing from CP/M 2.2 but in
;	CP/M 3.
;
sysmod_conost:				; Return 0xFF if console output ready
		ld l,0xff
		ret
sysmod_auxist:
		ld l,0xff
		ret
sysmod_auxost:
		ld l,0xff
		ret

sysmod_monitor:				; no monitor so just reboot
sysmod_reboot:
		; if you have no reboot just spin here
		ld a,1			; reboot
		out (29),a
failed:					; shouldn't get here
		jr failed

sysmod_joystick:
		ld hl,0			; No sticks
sysmod_conconf:				; Not supported
sysmod_auxconf:
		ret

		
sysinfo:
		.byte 8			; mumber of banks
		.byte 2			; feature flags (timer)
		.byte 10		; interrupt to 1/10ths divider
		.byte 0xff		; no swap
		.word 0xC000		; common start
		.word 0			; console doesn't support config
		.word 0			; aux doesn't support config
