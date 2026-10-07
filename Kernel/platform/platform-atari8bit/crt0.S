#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

;
;	We kick off in discard as we know where it is anyway. At least as a
;	guess as we don't have a loader yet.
;
		.discard
go:
		sei			; interrupts off
		cld			; decimal off
		ldx #$FF
		txs			; Stack (6502 not C)

		lda #<kstack_top	; C stack
		sta @sp
		lda #>kstack_top
		sta @sp+1 

		lda #<_udata
		sta @tmp
		lda #>_udata
		sta @tmp+1

		lda #0
		tay
		ldx #2
wipeud:
		sta (@tmp),y
		iny
		bne wipeud
		inc @tmp+1
		dex
		bne wipeud

		lda #<__bss
		sta @tmp
		lda #>__bss
		sta @tmp+1

		lda #0
		tay
		ldx #>__bss_size
		beq bss_wipe_tail
bss_wiper_1:	sta (@tmp),y
		iny
		bne bss_wiper_1
		inc @tmp+1
		dex
		bne bss_wiper_1

bss_wipe_tail:
		cpy #<__bss_size
		beq gogogo
		sta (@tmp),y
		iny
		bne bss_wipe_tail

gogogo:
		jsr init_early
		jsr init_hardware
		jsr _fuzix_main		; Should never return
		sei			; Spin
stop:		jmp stop

vectors:
		; To copy into place TODO
		.word	vector
		.word	_plt_reboot		; does it matter ???
		.word	nmi_handler

		.common

; We may want to move some common across the top of each bank but we need
; to be careful to pack it right. Possibly also use 0x0400-0x0FFF if using
; RAMBO style expansions in future. Things to ponder TODO

		.export stub
		.export stub_end
stub:
		.ds 700
stub_end:
;
;	Overlay specific init
;
		.overlay1
		.overlay2
		.overlay3
		.overlay4		; Will use for video and buffers

screen:		.ds 40 * 24
dlist:		.byte	0x70,0x70,0x70
		; 24 blank lines then set the start
		.byte	0x42
		.word	screen
		; Render 24 lines
		.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
		.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
		.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
		; Wait for vblank and return
		.byte	0x41
		.word	dlist

		; Then  skip 32
		.ds	32

		; We are now at 0x4400
		; Font will go here
		.ds	1024	; (or can we page before and lose 32)

		; Probably want to bank buffers here and if we can get
		; all of execve / user access and buffers here we can
		; do conventional rargs/wargs very very carefully.


		; We are now at about 4E00 once we allow for buffers
		; We now need all user copiers, block dev helpers, video
		; and execve/rargs/wargs stuffed into this bank
		.export _bufdata
_bufdata:
		.ds	512 * NBUFS
