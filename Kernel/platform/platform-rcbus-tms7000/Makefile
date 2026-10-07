LIBPATH=../../Library/libs

CSRCS += devices.c main.c devtty.c
DISCARD_CSRCS = discard.c

DISCARD_DSRCS = ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c
DISCARD_DSRCS += ../../dev/tinyide_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinysd.c  ../../dev/tinyide.c

CROSS_CCOPTS += -I../../dev/

ASRCS = crt0.S commonmem.S rcbus-tms7000.S tricks.S
DASRCS =

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))

OBJS  = $(AOBJS) $(COBJS) $(DISCARD_COBJS) $(DISCARD_DOBJS) $(DAOBJS) $(DOBJS)

JUNK = *.o *.lst *.asm *.sym *.rst

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -Tdiscard $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $<

$(DAOBJS): %.o: ../../dev/%.s
	$(CROSS_AS) $(ASOPTS) $<

# Need to make discard work yet
$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -Tdiscard $<

clean:
	rm -f $(OBJS) $(JUNK)  core *~ bootblock.bin bootblock fuzix.bin loader.tmp

bootblock: bootblock.S
	fcc -c -mtms7000 bootblock.S
	ld7000 -b bootblock.o -o bootblock.bin
	dd if=bootblock.bin of=bootblock bs=1 skip=512 count=448

image: bootblock
	$(CROSS_LD) -b -Z 0 -S 0x0500 -f SsLDBbXC -o fuzix.bin crt0.o devices.o main.o \
	discard.o commonmem.o tricks.o rcbus-tms7000.o devtty.o \
	../../start.o ../../version.o ../../cpu-tms7000/lowlevel-tms7000.o \
	../../mm/bankfixed.o ../../timer.o ../../kdata.o  ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o \
	../../syscall_fs3.o ../../syscall_exec.o ../../syscall_exec16.o  \
	../../dev/tinydisk.o ../../dev/tinysd.o ../../dev/tinyide.o \
	../../dev/tinydisk_discard.o ../../dev/tinysd_discard.o \
	../../dev/tinyide_discard.o \
	../../blk512.o ../../cpu-tms7000/usermem_std-tms7000.o -m fuzix.tmpmap /opt/fcc/lib/tms7000/libtms7000.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	cp fuzix.bin ../../fuzix.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	dd if=../../fuzix.bin of=fuzix.img bs=512 skip=2
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the bootstrap loader
	dd if=bootblock of=$(IMAGES)/disk.img bs=512 conv=notrunc
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.img of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
