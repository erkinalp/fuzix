# M20 Z8001 FUZIX Port — Build & Test Commands

All commands assume CWD is the fuzix root: `/Users/paxia/Projects/fuzix`

## Full rebuild (kernel + init + shell + fs + CHD)

```bash
# Kernel
cd /Users/paxia/Projects/fuzix/Kernel && TARGET=m20 make -j4

# Init
cd /Users/paxia/Projects/fuzix/Kernel/platform/platform-m20/userspace && make clean && make

# C library (only needed after changing Makefile.z8000 or syscall_z8000.c)
cd /Users/paxia/Projects/fuzix/Library/libs && \
  FUZIX_ROOT=/Users/paxia/Projects/fuzix USERCPU=z8000 make -f Makefile.z8000 clean && \
  FUZIX_ROOT=/Users/paxia/Projects/fuzix USERCPU=z8000 make -f Makefile.z8000

# Shell
cd /Users/paxia/Projects/fuzix/Applications/V7/cmd/sh && rm -f sh *.o && FUZIX_ROOT=/Users/paxia/Projects/fuzix USERCPU=z8000 make -f Makefile.z8000 sh

# Filesystem + HD + CHD
cd /Users/paxia/Projects/fuzix && \
dd if=/dev/zero of=/tmp/fuzix_fs.img bs=512 count=16384 2>/dev/null && \
Standalone/mkfs -X /tmp/fuzix_fs.img 256 16384 && \
Standalone/ucp /tmp/fuzix_fs.img << 'UCPEOF'
mkdir /dev
mknod /dev/tty1 020666 513
mkdir /tmp
mkdir /bin
bget Kernel/platform/platform-m20/userspace/init.bin /init
chmod 755 /init
cd /bin
bget Applications/V7/cmd/sh/sh sh
chmod 755 sh
bget Applications/util/echo echo
chmod 755 echo
bget Applications/util/cat cat
chmod 755 cat
bget Applications/util/ls ls
chmod 755 ls
bget Applications/util/rm rm
chmod 755 rm
bget Applications/util/cp cp
chmod 755 cp
bget Applications/util/mkdir mkdir
chmod 755 mkdir
bget Applications/util/rmdir rmdir
chmod 755 rmdir
bget Applications/util/chmod chmod
chmod 755 chmod
bget Applications/util/chown chown
chmod 755 chown
bget Applications/util/ps ps
chmod 755 ps
bget Applications/util/sleep sleep
chmod 755 sleep
bget Applications/util/sync sync
chmod 755 sync
bget Applications/util/true true
chmod 755 true
bget Applications/util/false false
chmod 755 false
bget Applications/util/pwd pwd
chmod 755 pwd
bget Applications/util/env env
chmod 755 env
bget Applications/util/grep grep
chmod 755 grep
bget Applications/util/head head
chmod 755 head
bget Applications/util/tail tail
chmod 755 tail
bget Applications/util/wc wc
chmod 755 wc
bget Applications/util/sort sort
chmod 755 sort
bget Applications/util/uname uname
chmod 755 uname
bget Applications/util/date date
chmod 755 date
bget Applications/util/od od
chmod 755 od
bget Applications/util/stty stty
chmod 755 stty
bget Applications/util/reboot reboot
chmod 755 reboot
bget Applications/V7/cmd/test test
chmod 755 test
UCPEOF
cd Kernel/platform/platform-m20 && \
python3 mkm20hd.py bootloader.bin fuzix.text.bin fuzix.data.bin /tmp/m20_fuzix.img /tmp/fuzix_fs.img && \
cd /Users/paxia/Projects/mame_latest/mame && \
chdman createhd -i /tmp/m20_fuzix.img -o hard/m20_fuzix.chd -chs 180,6,32 -ss 256 -c none -f
```

## Run in MAME

Console is on the M20 CRT/keyboard (tty1). Serial port is kprintf debug only.

```bash
cd /Users/paxia/Projects/mame_latest/mame && \
./m20 m20 -bios 2 -ramsize 512k -hard1 hard/m20_fuzix.chd
```

### With serial debug capture
```bash
# Terminal 1 (serial debug output):
stty raw -echo; nc -l 2323; stty sane

# Terminal 2:
cd /Users/paxia/Projects/mame_latest/mame && \
./m20 m20 -bios 2 -ramsize 512k -hard1 hard/m20_fuzix.chd \
    -rs232 null_modem -bitb socket.localhost:2323
```

### Headless with debug script
```bash
cd /Users/paxia/Projects/mame_latest/mame && \
cat > /tmp/mame_dbg.txt << 'CMDS'
go
CMDS
./m20 m20 -bios 2 -ramsize 512k -hard1 hard/m20_fuzix.chd \
    -debug -debugscript /tmp/mame_dbg.txt -debuglog \
    -video none -sound none -seconds_to_run 30
```

## Syscall wrapper generator

`Library/tools/syscall_z8000.c` generates all syscall wrappers for Z8001.
After editing, rebuild with:
```bash
cd Library/tools && gcc -I../../Kernel/include -o syscall_z8000 syscall_z8000.c
cd Library/libs && ../tools/syscall_z8000
```
Then do a full library rebuild (clean + make).

### Arg type codes
- `'w'` — 16-bit unsigned, zero-extended to 32-bit (`clr rH; ld rL, stack`)
- `'s'` — 16-bit signed, sign-extended to 32-bit (`ld rL, stack; ld rH, rL; sra rH, #15`)
- `'l'` — 32-bit (pointer/long), loaded directly (`ldl rr, stack`)

### Syscalls that return 32-bit pointers
sbrk (31), signal (35), _sigdisp (59), memalloc (64) — these skip the
`ld r2, r3` truncation so the full segmented pointer is returned.

## Get kernel symbol addresses
```bash
z8k-coff-nm /Users/paxia/Projects/fuzix/Kernel/platform/platform-m20/fuzix.bin | \
    grep -E '_e_syscall|_doexec|_plt_relocate|_outchar'
```

## MAME debugger cheat sheet
- Breakpoint: `bp <addr>,1,{printf "msg\n";g}`
- I/O watchpoint: `wpiset <port>,<len>,w`
- Memory watchpoint: `wpset <addr>,<len>,rw` (may not work for Z8001 user space)
- Instruction trace: `trace <file>,0` / `trace off`
- Conditional BP: `bp <addr>,<condition>,{action}`

## CHD geometry (NEVER change)
`-chs 180,6,32 -ss 256 -c none`

## Key facts
- `-X` flag required for mkfs (big-endian)
- Device numbering: major 0=hd, major 1=fd (matches basefs.pkg standard)
- Root mounts ro by default — /etc/rc does `fsck -a /` then `remount -n / rw`
- Do NOT force rw at boot (dirty flag breaks fsck)
- Default stack per userland binary: 8KB (ldz8k STACK=8192); shell uses 16KB (-s 16384)
- Full init with login: default user `root`, no password
- chdman must run from /Users/paxia/Projects/mame_latest/mame
- Serial port (0xC1) is kprintf debug output only — not a user TTY
- CRT output goes through BIOS PROM put_char — interrupts disabled during call to prevent re-entrancy from keyboard echo
- Keyboard scan codes translated via 256-byte table from CP/M-8000 BIOS (S. Savitzky, Zilog 1982)
- Library must NOT use -DUSE_SYSMALLOC — kernel memalloc returns kernel-segment pointers unusable from user space on segmented Z8001
- Syscall wrappers must use `_errno` (with underscore) not `errno` — C symbols get underscore prefix on Z8000 COFF
- crt0 must compute `environ = ISP + 8` (address), not load `*(ISP+8)` (value)
- After changing config.h, `rm -f start.o` to force rebuild — make doesn't track config.h deps
