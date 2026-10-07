# Z8001 Signal Delivery

## Overview

Signal delivery on Z8001 segmented mode intercepts the return from a syscall
(or interrupt) and redirects execution to the user's signal handler before
returning to the interrupted user code.

## VDSO Layout (at codebase+0, 0x20 bytes)

```
Offset 0x00: sc #0; ret          — syscall entry (4 bytes)
Offset 0x04: signal unwind code  — restores context after signal handler (16 bytes)
Offset 0x14: unused              — padding to 0x20
```

The VDSO is copied to the start of each process's code area by `install_vdso()`
in `main.c`.

## Signal Frame (on user stack, 20 bytes)

When a signal is delivered, the kernel builds this frame on the user stack
(growing downward from the current NSP):

```
NSP+0:  VDSO unwind addr seg  (2)   ← return address for handler's ret
NSP+2:  VDSO unwind addr off  (2)      = codebase + 4
NSP+4:  signal number          (2)   ← argument to handler (at SP+4 after ret addr)
NSP+6:  padding                (2)
NSP+8:  saved r2               (2)   ← syscall return value (high word)
NSP+10: saved r3               (2)   ← syscall return value (low word)
NSP+12: original PC seg        (2)   ← where to resume after signal
NSP+14: original PC off        (2)
NSP+16: old NSP seg            (2)   ← user stack pointer before signal frame
NSP+18: old NSP off            (2)
```

## Delivery Flow (return_via_signal in lowlevel-z8000.S)

Entry state:
- rr2 = syscall return value
- rr10 = udata pointer (segmented)
- Kernel stack: [saved_rr10][SC identifier][FCW][PC_seg][PC_off]

Steps:
1. Save rr2 (syscall return) and rr8 (callee-saved) on kernel stack
2. Read signal number from `u_cursig`, clear it
3. Look up handler address from `u_sigvec[sig]`
4. Read current user NSP into rr8 via ldctl (clobbers rr8, hence the save)
5. Build signal frame on user stack (write downward using segmented pointer)
6. Update NSP to point to top of signal frame
7. Patch the IRET frame's PC to the signal handler address
8. Restore rr8, discard saved rr2, restore rr10, IRET

IRET switches to normal mode and jumps to the signal handler.

## Signal Handler Execution

The handler runs in user space (normal mode) with:
- SP pointing to the signal frame
- Return address = VDSO unwind (codebase + 4)
- Signal number accessible at SP+4 (standard C calling convention)

The handler prototype is: `void handler(int sig)`

When the handler does `ret`, it pops the return address and jumps to the
VDSO signal unwind code.

## VDSO Signal Unwind (at codebase+4)

```asm
add  r15, #4          ; skip signal number + padding
pop  r2, @rr14        ; restore syscall return r2
pop  r3, @rr14        ; restore syscall return r3
popl rr4, @rr14       ; original PC into rr4
popl rr6, @rr14       ; old NSP into rr6
ldl  rr14, rr6        ; restore user stack pointer
jp   @rr4             ; return to interrupted code
```

After the unwind:
- r2/r3 have the original syscall return value
- rr14 (NSP) is restored to the pre-signal value
- Execution continues at the instruction after the original syscall

## Register Preservation

The signal delivery code uses R8/R9 to read the user NSP (`ldctl r8, nspseg;
ldctl r9, nspoff`). These are callee-saved registers that user code expects
to be preserved across syscalls. The delivery code saves rr8 on the kernel
stack before clobbering it and restores it before IRET, so the user's R8/R9
values survive signal delivery.

The VDSO unwind clobbers r4, r5, r6, r7 (used as temporaries for PC and
old NSP). These are caller-saved registers, so this is safe when returning
from a syscall.

## Limitations

- Signal delivery is currently only implemented for the syscall return path
  (`return_via_signal` in `_e_syscall`). Signals during interrupt return
  (NVI handler) use the same check but share the same delivery code.
- Nested signals are not handled — if a signal arrives during signal handler
  execution, it will be delivered on the next syscall return.
- The signal handler vector is not automatically reset to SIG_DFL; the C
  signal handling code in `chksigs()` manages this.
