;
; dispatches vt calls to different screen routines
;

	.commondata

	.export _curtty
_curtty:
	.byte 0

	.common

	.export _clear_across
_clear_across:
	lda	_curtty
	lbeq	_m6847_clear_across
	jmp	_vc_clear_across

	.export _clear_lines
_clear_lines:
	lda	_curtty
	lbeq	_m6847_clear_lines
	jmp	_vc_clear_lines

	.export _scroll_up
_scroll_up:
	lda	_curtty
	lbeq	_m6847_scroll_up
	jmp	_vc_scroll_up

	.export _scroll_down
_scroll_down:
	lda	_curtty
	lbeq	_m6847_scroll_down
	jmp	_vc_scroll_down

	.export _plot_char
_plot_char:
	lda	_curtty
	lbeq	_m6847_plot_char
	jmp	_vc_plot_char

	.export _cursor_off
_cursor_off:
	lda	_curtty
	lbeq	_m6847_cursor_off
	jmp	_vc_cursor_off

	.export _cursor_on
_cursor_on:
	lda	_curtty
	lbeq	_m6847_cursor_on
	jmp	_vc_cursor_on

	.export _cursor_disable
_cursor_disable:
	rts

	.export _vtattr_notify
_vtattr_notify:
	lda	_curtty
	lbeq	_m6847_vtattr_notify
	jmp	_vc_vtattr_notify

	.export _video_cmd
_video_cmd:
	lda	_curtty
	lbeq	_m6847_video_cmd
	rts

	.export _video_read
_video_read:
	lda	_curtty
	lbeq	_m6847_video_read
	rts

	.export _video_write
_video_write:
	lda	_curtty
	lbeq	_m6847_video_write
	rts

