# Fork-consolidation TODO

Tracking the remainder after merging Codeberg upstream + tailwind/pc3 + the
other forks (PR #8 / devin/merge-pc3). Written 2026-10-06.

## Remaining fork work (not yet imported)

### wez/picocalc — retail PicoCalc drivers, needs wiring decision
wez's fork has `i2ckbd` + `lcdspi` drivers targeting the retail PicoCalc
product, while pc3 brought its own complete stack (HSTX display,
`usbkbd.c`, `i2cuser.c`; vendored `kbd_decode.c` is byte-identical to
MicroPython's rp2 port). Decide whether to wire wez's drivers as an
alternative display/kbd backend or drop them.

### eljacobs83 — overlaps to dedupe
- CYW43 wireless driver vs pc3's own lwIP/CYW43 path — pick one
- eljacobs83's rpipico rework is PicoCalc-only; dedupe against pc3's
  rpipico tree before adopting
- eljacobs83 fs extent plumbing was skipped deliberately: FS32 mandates
  s_shift==0 (kernel.h, mount rejects otherwise) so extents are a
  classic-FS-only no-op in this tree. Revisit only if a bigger-block
  FS32 variant is ever designed (see below).

### eugenechertikhin/fuzix-new — build system + restructure
Wholesale tree restructure + parallel CMake build for his layout —
not mergeable as-is. Already imported: `Standalone/mkfs_fat.c`,
`Standalone/fsck_fat.c` (+ Makefile wiring). Remainder to evaluate:
platform ports 8086/ibmpc, ESP8266, rcbus-6800, zx* variants, and the
CMake build system itself.

### nick-less — Commodore PET-8296 port (WIP)
`Kernel/platform/platform-pet-8296/` imported; upstream WIP state:
"panic noinit", "throws ide error". Needs completion before the port
can boot.

### Codeberg open PRs (upstream, unmerged) — evaluate for import
- #1319 agon: Wiznet + w5x00 driver
- #1308 cpcsme: plt_idle polling
- #1205 PDP-11/40 port
- #1191 pollardd: 2048 display fix
- #1190 pollardd: rpipico `make clean` fix

### FS32 extent / bigger-block design
Design doc candidate: allow larger-than-512B logical blocks / extents
in FS32 (v2 format) — needs s_shift plumbing through filesys + tools.

## Upstream issues (EtchedPixels/FUZIX, archived) — cross-check result

SOLVED downstream (verified in this tree):
- #961 /etc/profile never executed — fixed in Applications/V7/cmd/sh/main.c
- #1076 ar + ftruncate — both present
- #1192 sys/termios.h — 2048 draw.c now includes <termios.h>
- #1188 rpipico README/build — pc3 rewrote it (BUILDING-PC3.md)
- #1032 rpipico — superseded by pc3 port
- #957 armm0 libm linkage — Makefile.armm0 now lists full libm
- #555 netd TCP — replaced by pc3's lwIP-based netd
- #1075 version.c missing on rpipico cmake path — FIXED in PR #8
- #1147 dosdir -r infinite loop — FIXED in PR #8 (skip . and ..)
- #1172 2048 draw.c build failure — upstream portability fixes landed
- #904 Z180DMA uzero login error — z180 reworked on Codeberg Sept 2026
  (fix timers / remaining bugs / low-level); VERIFY on hardware

STILL OPEN — kernel/core:
- #686 fork(): nready corner case
- #715 init: no failsafe for instantly-exiting respawn: entries
- #1167 panic in bdread/bdwrite on invalid device (Z80-MBC2) — should
  be a graceful error
- #1091 ESP8266 FATAL EXCEPTION 28 (Nov-2024 Codeberg fs fixes may
  have helped — verify)
- #1194 lowlevel-68000 __hard_irqrestore: SR restored from 6(sp),
  reporter argues 4(sp) — verify calling convention
- #967 fsck: bad blocks reported as owned by inode 0

STILL OPEN — platform/hardware:
- #1077 ZX video corruption (video5)
- #996 PCW8256 floppy driver problems
- #627 floppy formatting support missing

STILL OPEN — performance & usability:
- #1026 ls speed, #1025 stdio slowness, #557 fsck slow on big fs,
  #383 sort blocks before writing, #626 optimization wishlist,
  #556 regexp memory, #549 levee editor improvements

STILL OPEN — features:
- #658 blkdev: removable-media/MBR handling
- #652 build-filesystem-ng ordering
- #647 disk geometry in superblock
- #637 spawn() syscall
- #594 6809 floating point
- #577 PDP-11 toolchain tracking
- #567 sound chip abstraction
- #772 ucp/fsck on +3 .dsk images
- #290/#295/#292/#648 Level-2 blockers (select/poll debugging,
  rlimits, core dumps/ptrace, fcntl locking)
- #1021+#769 Wiznet +3 / uKLA
- #962 Heirloom toolchain eval
- #1040 Mizar32 discussion
- #1178 0.5rc build checklist sweep

(GitHub Issues are currently disabled on this repository — this file is
the to-do list until they're enabled.)
