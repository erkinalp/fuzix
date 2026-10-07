        ; exported symbols (used by devrd.c)
        .export _rd_read
        .export _rd_write

	.code

; kernel calls rd_read(), rd_write(); we just set a flag and then pass control to rd_transfer()
_rd_write:
        ld a, #1
        jr _rd_go
_rd_read:
        xor a
_rd_go: ld (_rd_reverse), a
        jp _rd_transfer
