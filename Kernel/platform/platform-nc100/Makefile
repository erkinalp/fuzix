
CSRCS = devlpr.c devtty.c devrd.c devaudio.c devgfx.c
CSRCS += devices.c main.c tc8521.c bank.c

ASRCS = nc100.S crt0.S
ASRCS += tricks.S commonmem.S

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
OBJS  = $(COBJS) $(AOBJS)

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

clean:
	rm -f $(OBJS) core *~ bootblock.img bootblock.tmp nc100emu.bin nc100emu.tmp

bootblock.img: bootblock.S
	fcc -mz80 bootblock.S -c
	ldz80 -b bootblock.o -o bootblock

image: bootblock.img nc100emu.bin
	$(CROSS_LD) -b -C 0x0 -S 0xF000 -X 0xE000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o nc100.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	tricks.o main.o devrd.o devices.o bank.o \
	devlpr.o devtty.o devaudio.o devgfx.o tc8521.o \
	../../timer.o ../../kdata.o ../../devio.o ../../audio.o \
	../../filesys.o ../../blk512.o ../../process.o ../../vt.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../font/font6x8.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.img <../../fuzix.map
	dd if=bootblock of=fuzix.img bs=1 conv=notrunc

nc100emu.bin: nc100emu.S
	fcc -mz80 nc100emu.S -c
	ldz80 -b -C 0x100  nc100emu.o -o nc100emu.tmp
	dd if=nc100emu.tmp bs=256 skip=1 of=nc100emu.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)
diskimage: image
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-mini-filesystem $(ENDIANFLAG) $(IMAGES)/pcmcia.tmp 64 1408)
	dd if=fuzix.img bs=327680 conv=sync >pcmcia.tmp2
	cat pcmcia.tmp2 $(IMAGES)/pcmcia.tmp >$(IMAGES)/pcmcia.img
	rm -f $(IMAGES)/pcmcia.tmp pcmcia.tmp2
	cp nc100emu.bin $(IMAGES)
