#include "../../cpu-tms7000/kernel-tms7000.def"

; Overlay the loader

	.abs
	.org 0x200
#include "../../cpu-tms7000/std-commonmem.s"
