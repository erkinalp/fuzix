;
;        zx128 vt primitives
;

        ; exported symbols
        .export _plot_char
        .export _scroll_down
        .export _scroll_up
        .export _cursor_on
        .export _cursor_off
	.export _cursor_disable
        .export _clear_lines
        .export _clear_across
        .export _do_beep
	.export _fontdata_8x8
	.export _curattr

	; Build the video library as the only driver

#define	ZXVID_ONLY
#define SCREENBASE	0x40
#define VIDEO_MAP	call map_video
#define VIDEO_UNMAP	call map_kernel

_fontdata_8x8	.equ	0x7D00		; routines expect this
					; to point to space char

	.common
#include "../../dev/zx/video.S"


