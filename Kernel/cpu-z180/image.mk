LIBOBJ = start.o version.o timer.o kdata.o usermem.o \
         devio.o filesys.o blk512.o process.o inode.o \
         syscall_exec.o syscall_exec16.o syscall_fs.o \
         syscall_fs2.o syscall_fs3.o syscall_proc.o \
         syscall_other.o syscall_net.o network.o \
         tty.o mm.o mm/memalloc_none.o \
         mm/banksplit.o swap.o devsys.o devinput.o vt.o

LIBOBJ += cpu-z180/lowlevel-z180.o cpu-z180/usermem_std-z180.o

tools/visualizefcc: tools/visualizefcc.c

tools/hogfather: tools/hogfather.c

tools/pack85: tools/pack85.c

tools/packdiscard: tools/packdiscard.c

tools/doubleup: tools/doubleup.c

tools/makejv3: tools/makejv3.c

tools/trslabel: tools/trslabel.c

cpm-loader-fcc/cpmload.bin: cpm-loader-fcc/cpmload.S cpm-loader-fcc/fuzixload.S cpm-loader-fcc/makecpmloader.c
	+$(MAKE) -C cpm-loader-fcc

libfuzix.a: $(LIBOBJ)
	rm -f libfuzix.a
	ar qc libfuzix.a `lorderz80 $(LIBOBJ) | ftsort`

fuzix.bin: target $(OBJS) libfuzix.a tools/pack85 tools/packdiscard tools/visualizefcc tools/doubleup cpm-loader-fcc/cpmload.bin tools/makejv3 tools/trslabel tools/hogfather
	+$(MAKE) -C platform/platform-$(TARGET) image
	(cd platform/platform-$(TARGET); ../../tools/visualizefcc <../../fuzix.map)
	tools/hogfather fuzix.map | sort -nr >fuzix.hogs
