; Flexible 16K banks on SAMx8
;
; Derived from MOOH platform code
;
; Copyright 2015-2018 Tormod Volden
; Copyright 2025-2026 Ciaran Anscomb

	; exported
	.export map_kernel
	.export map_proc
	.export map_proc_a
	.export map_proc_always
	.export map_save
	.export map_restore
	.export mmu_remap_x

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.common

; must preserve register a but not x
map_kernel:
	clr map_copy
	sta 0xffd5		; task 1 (kernel)
	rts

map_restore:
	lda map_store
	beq map_kernel
	; fall through

; might be called with interrupts enabled from drivers
map_proc_always:
	pshs cc,a,b
	orcc #0x10
	ldd _udata+U_DATA__U_PAGE
	std $ff30
	ldd _udata+U_DATA__U_PAGE2
	std $ff32
	lda #1
	sta map_copy
	sta 0xffd4		; task 0 (user)
	puls cc,a,b,pc

; called by I/O drivers (also for swapping)
map_proc:
	cmpx #0
	beq map_kernel
	pshs cc
	orcc #0x10
	bsr map_proc_a
	puls cc,pc

; called directly by switchin
map_proc_a:
	bsr mmu_remap_x
	lda #1
	sta map_copy
	sta 0xffd4		; task 0 (user)
	rts

mmu_remap_x:
	ldd ,x
	std $ff30
	ldd 2,x
	std $ff32
	rts

map_save:
	lda map_copy
	sta map_store
	rts

	.commondata

map_store:
	.word 0
map_copy:
	.word 0
