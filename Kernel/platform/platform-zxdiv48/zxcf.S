setup:
	ld	bc, 0x00BF	; setup port number
	ld	a, 0x05
	out	(0xfe),a
	ld	a, (_td_raw)	; and count
	or 	a
	ret	z
	dec	a
	jp	z, map_buffers
	ld	a,(_td_page)
	jp	map_for_swap

_zxcf_read_data:
	push	bc
	call	setup
	; The ZXCF design is sucky as we have a 16bit port decode
	ld a,#0x40
            
next4:
        ini
        inc	b
        ini
        inc	b
        ini
        inc	b
        ini
        inc	b
        dec	a
        jr	nz, next4
        ld	a, 0x02
        out	(0xfe),a
        ld	a, 0x40
            
next4_2:
        ini
        inc	b
        ini
        inc	b
        ini
        inc	b
        ini
        inc	b
        dec	a
	jr	nz, next4_2
done:
	ld	a,(_vtborder)
	out	(0xfe),a

	ld	a,(_td_raw)
	or	a
	pop	bc
	ret	z
	jp	map_kernel_restore               ; else map kernel then return

_zxcf_write_data:
	push	bc
	call	setup
	; The ZXCF design is sucky as we have a 16bit port decode
	ld a,	0x40
  
w_next_4:          
        outi
        inc	b
        outi
        inc	b
        outi
        inc	b
        outi
        inc	b
        dec	a
        jr	nz, next4
        ld	a, 0x02
        out	(0xfe),a
        ld	a, 0x40
            
w_next4_2:
        outi
        inc	b
        outi
        inc	b
        outi
        inc	b
        outi
        inc	b
        dec	a
	jr	nz, w_next4_2
