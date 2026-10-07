/*
 *	Generate the syscall stubs for Z8001 (segmented mode).
 *
 *	Z8001 calling convention (z8k-coff-gcc -msegmented):
 *	  int = 16-bit, pointers = 32-bit, long = 32-bit
 *	  Arguments on stack, right-to-left
 *	  After CALL: rr14(#0)=retaddr(4), rr14(#4)=first arg, ...
 *
 *	Kernel syscall convention:
 *	  R1 = syscall number
 *	  RR2 = arg0, RR4 = arg1, RR6 = arg2 (all 32-bit)
 *	  SC #0 to enter kernel
 *	  Return: RR2 = retval (or -1), R1 = error code (or 0)
 *
 *	Each arg on the C stack is either 2 bytes (int/uint16_t) or
 *	4 bytes (pointer/long). The type table below encodes this so
 *	we generate correct stack offsets and zero-extension for 16-bit args.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "syscall_name.h"

/*
 * Argument types: 'w' = 16-bit word, 'l' = 32-bit long/pointer.
 * Derived from Library/include/syscalls.h declarations.
 * Varargs syscalls use their most common argument form.
 */
static const char *syscall_types[NR_SYSCALL] = {
	"w",	/* 0: _exit(int) */
	"lww",	/* 1: open(ptr, int, mode_t) — varargs */
	"w",	/* 2: close(int) */
	"ll",	/* 3: rename(ptr, ptr) */
	"lww",	/* 4: mknod(ptr, mode_t, dev_t) */
	"ll",	/* 5: link(ptr, ptr) */
	"l",	/* 6: unlink(ptr) */
	"wlw",	/* 7: read(int, ptr, int) */
	"wlw",	/* 8: write(int, ptr, int) */
	"wlw",	/* 9: _lseek(int, off_t*, int) */
	"l",	/* 10: chdir(ptr) */
	"",	/* 11: sync() */
	"lw",	/* 12: access(ptr, int) */
	"lw",	/* 13: chmod(ptr, mode_t) */
	"lww",	/* 14: chown(ptr, uid_t, gid_t) */
	"ll",	/* 15: _stat(ptr, ptr) */
	"wl",	/* 16: _fstat(int, ptr) */
	"w",	/* 17: dup(int) */
	"",	/* 18: getpid() */
	"",	/* 19: getppid() */
	"",	/* 20: getuid() */
	"w",	/* 21: umask(mode_t) */
	"ll",	/* 22: _statfs(ptr, ptr) */
	"lll",	/* 23: execve(ptr, ptr, ptr) */
	"wlw",	/* 24: _getdirent(int, ptr, int) */
	"w",	/* 25: setuid(uid_t) */
	"w",	/* 26: setgid(gid_t) */
	"lw",	/* 27: _time(ptr, uint16_t) */
	"lw",	/* 28: _stime(ptr, uint16_t) */
	"wwl",	/* 29: ioctl(int, int, ptr) — varargs */
	"l",	/* 30: brk(ptr) */
	"l",	/* 31: sbrk(intptr_t) — 32-bit */
	"wl",	/* 32: _fork(uint16_t, ptr) */
	"llw",	/* 33: mount(ptr, ptr, int) */
	"lw",	/* 34: _umount(ptr, int) */
	"wl",	/* 35: signal(int, sighandler_t) */
	"ww",	/* 36: dup2(int, int) */
	"w",	/* 37: _pause(unsigned int) */
	"w",	/* 38: _alarm(unsigned int) */
	"sw",	/* 39: kill(pid_t, int) */
	"l",	/* 40: pipe(ptr) */
	"",	/* 41: getgid() */
	"l",	/* 42: times(ptr) */
	"ll",	/* 43: utime(ptr, ptr) */
	"",	/* 44: geteuid() */
	"",	/* 45: getegid() */
	"l",	/* 46: chroot(ptr) */
	"wwl",	/* 47: fcntl(int, int, long) — varargs */
	"w",	/* 48: fchdir(int) */
	"ww",	/* 49: fchmod(int, mode_t) */
	"www",	/* 50: fchown(int, uid_t, gid_t) */
	"lw",	/* 51: mkdir(ptr, mode_t) */
	"l",	/* 52: rmdir(ptr) */
	"",	/* 53: setpgrp() */
	"lw",	/* 54: _uname(ptr, int) */
	"slw",	/* 55: waitpid(pid_t, ptr, int) */
	"lwww",	/* 56: _profil(ptr, u16, u16, s16) — 4 args, rare */
	"wwl",	/* 57: uadmin(int, int, ptr) */
	"w",	/* 58: nice(int) */
	"wl",	/* 59: _sigdisp(int, ptr) */
	"ww",	/* 60: flock(int, int) */
	"",	/* 61: getpgrp() */
	"",	/* 62: yield() */
	"l",	/* 63: acct(ptr) */
	"w",	/* 64: memalloc */
	"l",	/* 65: memfree(ptr) */
	"l",	/* 66: __netcall(ptr) */
	"wl",	/* 67: _ftruncate(int, ptr) */
	"",	/* 68: nosys */
	"",	/* 69: nosys */
	"",	/* 70: nosys */
	"",	/* 71: nosys */
	"wl",	/* 72: _select(int, ptr) */
	"ll",	/* 73: setgroups(size_t, ptr) — size_t=32-bit */
	"wl",	/* 74: getgroups(int, ptr) */
	"wl",	/* 75: getrlimit(int, ptr) */
	"wl",	/* 76: setrlimit(int, ptr) */
	"ww",	/* 77: setpgid(pid_t, pid_t) */
	"",	/* 78: setsid() */
	"w",	/* 79: getsid(pid_t) */
};

/* Register pair names for args 0-2 */
static const char *regpair_hi[] = { "r2", "r4", "r6" };
static const char *regpair_lo[] = { "r3", "r5", "r7" };
static const char *regpair[]    = { "rr2", "rr4", "rr6" };

static char namebuf[256];

static void write_call(int n)
{
	FILE *fp;
	const char *types;
	int offset, arg, nargs;

	snprintf(namebuf, sizeof(namebuf),
		 "fuzixz8000/syscall_%s.S", syscall_name[n]);
	fp = fopen(namebuf, "w");
	if (fp == NULL) {
		perror(namebuf);
		exit(1);
	}

	types = syscall_types[n];
	nargs = strlen(types);
	if (nargs > 3)
		nargs = 3;	/* kernel only has 3 arg register pairs */

	int is_fork = (strcmp(syscall_name[n], "_fork") == 0);

	fprintf(fp, "\t.segm\n");
	fprintf(fp, "\t.text\n\n");
	fprintf(fp, "\t.globl\t_%s\n\n", syscall_name[n]);
	fprintf(fp, "_%s:\n", syscall_name[n]);

	/*
	 * Fork is special: save callee-saved registers on the user
	 * stack so the child (which gets a copy of user memory) can
	 * restore them.  Without this, the child returns from fork()
	 * with callee-saved registers trashed by kernel C code.
	 */
	if (is_fork) {
		fprintf(fp, "\tpushl\t@rr14, rr8\n");
		fprintf(fp, "\tpushl\t@rr14, rr12\n");
		offset = 4 + 8;  /* retaddr + 2 pushes */
	} else {
		offset = 4;
	}

	/* Load arguments from C stack into register pairs.
	 * Stack after CALL: rr14(#0) = return address (4 bytes),
	 * then args starting at rr14(#4).
	 * If fork, the pushes shift args by 8. */
	for (arg = 0; arg < nargs; arg++) {
		if (types[arg] == 'l') {
			/* 32-bit: load directly */
			fprintf(fp, "\tldl\t%s, rr14(#%d)\n",
				regpair[arg], offset);
			offset += 4;
		} else if (types[arg] == 's') {
			/* 16-bit signed: sign-extend to 32-bit pair */
			fprintf(fp, "\tld\t%s, rr14(#%d)\n",
				regpair_lo[arg], offset);
			fprintf(fp, "\tld\t%s, %s\n",
				regpair_hi[arg], regpair_lo[arg]);
			fprintf(fp, "\tsra\t%s, #15\n",
				regpair_hi[arg]);
			offset += 2;
		} else {
			/* 16-bit unsigned: zero-extend to 32-bit pair */
			fprintf(fp, "\tclr\t%s\n", regpair_hi[arg]);
			fprintf(fp, "\tld\t%s, rr14(#%d)\n",
				regpair_lo[arg], offset);
			offset += 2;
		}
	}

	/* Load syscall number and trap */
	fprintf(fp, "\tld\tr1, #%d\n", n);
	fprintf(fp, "\tsc\t#0\n");

	if (is_fork) {
		fprintf(fp, "\tpopl\trr12, @rr14\n");
		fprintf(fp, "\tpopl\trr8, @rr14\n");
	}

	/*
	 * u_retval is 32-bit (arg_t). On big-endian Z8001, a small value
	 * like 1 is 0x00000001: r2=0, r3=1. But C functions returning int
	 * (16-bit) expect the result in r2. Copy r3→r2 so 16-bit callers
	 * see the correct value. Skip this for syscalls that return 32-bit
	 * pointers (sbrk, signal, _sigdisp) — they need the full rr2.
	 */
	int returns_ptr = (n == 31 || n == 35 || n == 59 || n == 64);
	if (!returns_ptr)
		fprintf(fp, "\tld\tr2, r3\n");

	/* Error check: r1 = error code (0 = success) */
	fprintf(fp, "\ttest\tr1\n");
	fprintf(fp, "\tret\tz\n");
	fprintf(fp, "\tld\t_errno, r1\n");
	fprintf(fp, "\tret\n");

	fclose(fp);
}

static void write_call_table(void)
{
	int i;
	for (i = 0; i < NR_SYSCALL; i++)
		write_call(i);
}

static void write_makefile(void)
{
	int i;
	FILE *fp;

	fp = fopen("fuzixz8000/Makefile", "w");
	if (fp == NULL) {
		perror("fuzixz8000/Makefile");
		exit(1);
	}

	fprintf(fp, "# Autogenerated by tools/syscall_z8000\n");
	fprintf(fp, "CROSS_COMPILE=z8k-coff-\n");
	fprintf(fp, "CROSS_AS=$(CROSS_COMPILE)as\n");
	fprintf(fp, "CROSS_AR=$(CROSS_COMPILE)ar\n\n");

	fprintf(fp, "ASRCS = syscall_%s.S\n", syscall_name[0]);
	for (i = 1; i < NR_SYSCALL; i++)
		fprintf(fp, "ASRCS += syscall_%s.S\n", syscall_name[i]);

	fprintf(fp, "\nAOBJS = $(ASRCS:.S=.o)\n\n");
	fprintf(fp, "syslib.lib: $(AOBJS)\n");
	fprintf(fp, "\techo $(AOBJS) >syslib.l\n");
	fprintf(fp, "\t$(CROSS_AR) rc syslib.lib $(AOBJS)\n\n");
	fprintf(fp, "$(AOBJS): %%.o: %%.S\n");
	fprintf(fp, "\t$(CROSS_AS) -z8001 -o $@ $<\n\n");
	fprintf(fp, "clean:\n");
	fprintf(fp, "\trm -f $(AOBJS) $(ASRCS) syslib.lib syslib.l *~\n\n");

	fclose(fp);
}

int main(int argc, char *argv[])
{
	write_makefile();
	write_call_table();
	return 0;
}
