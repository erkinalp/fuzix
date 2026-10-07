ASRCS = crt0.S tricks.S commonmem.S zeta-v2.S monitor.S
ASRCS += ds1302-n8vem.S devrd_zeta2_hw.S
CSRCS = devices.c main.c devtty.c devrd_zeta2.c
DISCARD_CSRCS = discard.c devtty_discard.c
DISCARD_DSRCS = ../../dev/ds1302_discard.c ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c
DSRCS = ../../dev/devfd.c ../../dev/tinydisk.c ../../dev/tinyide.c
DSRCS += ../../dev/ds1302.c ../../dev/devrd.c
DASRCS = ../../dev/devfd_rbc.S ../../dev/tinyide_ppide_rbc.S ../../dev/devrd_hwu.S

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS) diskboot.bin

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) core *~ *.tmp bootrom.bin diskboot.bin fuzix.com fuzix.rom

diskboot.bin:	diskboot.S
	$(CROSS_AS) $(ASOPTS) diskboot.S
	ldz80 -b diskboot.o -o diskboot.tmp
	dd bs=512 skip=125 count=1 if=diskboot.tmp of=diskboot.bin

bootrom.bin:
	ldz80 -b bootrom.o -o bootrom.tmp
	dd if=bootrom.tmp of=bootrom.bin bs=136 conv=sync count=1

image: bootrom.bin
	$(CROSS_LD) -b -C 0x0088 -S 0xF000 -X0xD000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o zeta-v2.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	tricks.o main.o discard.o devrd_zeta2.o devrd_zeta2_hw.o \
	../../dev/devfd.o ../../dev/devfd_rbc.o devices.o monitor.o \
	../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bank16k.o ../../devsys.o \
	devtty.o devtty_discard.o ../../dev/devrd.o ../../dev/devrd_hwu.o \
	../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinyide.o ../../dev/tinyide_discard.o \
	../../dev/tinyide_ppide_rbc.o \
	../../dev/ds1302_rcbusu.o ../../dev/ds1302.o ../../dev/ds1302_discard.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.tmp <../../fuzix.map
	# Work around bugs in Fedora dd
	dd if=fuzix.tmp of=../../fuzix.bin bs=136 skip=1
	cat bootrom.bin ../../fuzix.bin > fuzix.tmp
	dd if=fuzix.tmp conv=sync bs=524288 count=1 of=fuzix.rom
	../../cpm-loader-fcc/makecpmloader ../../cpm-loader-fcc/cpmload.bin ../../fuzix.bin 0x88 fuzix.com
	../../cpm-loader-fcc/makecpmloader ../../cpm-loader-fcc/fuzixload.bin ../../fuzix.bin 0x88 fuzix

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# ROM
	cp fuzix.rom $(IMAGES)
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the boot block into the partition sector
	dd if=diskboot.bin bs=446 count=1 of=$(IMAGES)/disk.img conv=notrunc
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=../../fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
