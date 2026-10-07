# 1 "commonmem.S"
;
        ; exported symbols
        .export _ub
        .export _udata
        .export kstack_top
        .export istack_top
        .export istack_switched_sp

        .common

_ub:    ; first 512 bytes: starts with struct u_block, with the kernel stack working down from above
_udata:
kstack_base:
	.ds 512
kstack_top:

	.common

        ; next 256 bytes: 254 byte interrupt stack, then 2 byte saved stack pointer
istack_base:
	.ds 254
istack_top:
istack_switched_sp: .word 0
