
CSRCS = devices.c main.c devinput.c devtty.c

# Code that must be present for the bootstrap
CISRCS = devsdc.c

CDSRCS = discard.c 

DSRCS = ../../dev/devdw.c ../../dev/tinydisk.c ../../dev/tinyide.c
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c

ASRCS = crt0.S coco2.S ide.S usermem.S sdc.S
ASRCS += bootstrap.S bootstrap_sdc.S #bootstrap_dw.S
ASRCS += tricks.S commonmem.S ../../dev/drivewire/drivewire.S video.S

COBJS = $(CSRCS:.c=$(BINEXT))
CIOBJS = $(CISRCS:.c=$(BINEXT))
C3OBJS = $(C3SRCS:.c=$(BINEXT))
CDOBJS = $(CDSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.S=$(BINEXT))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(C3OBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(CIOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)

$(COBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(CIOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG1) -c $<

$(CDOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $<

$(DDOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(AOBJS): %$(BINEXT): %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o *~ fuzixide.rom fuzixsdc.rom fuxix.img

image:
	$(CROSS_LD) -b -X 0x0400 -C 0xC000 -S 0x1A00 -f CSsLDBbX -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o bootstrap.o commonmem.o coco2.o discard.o ../../mm/simple.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../dev/drivewire/drivewire.o ../../dev/devdw.o ../../dev/tinyide.o \
	../../dev/tinyide_discard.o ide.o ../../dev/tinydisk.o \
	../../dev/tinydisk_discard.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_exec.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o usermem.o ../../syscall_fs2.o \
	../../syscall_exec16.o devtty.o ../../vt.o video.o  ../../syscall_fs3.o \
	../../blk512.o ../../font/font8x8.o devsdc.o sdc.o ../../devinput.o devinput.o \
	/opt/fcc/lib/6809/lib6809.a
	# This has changed with the discard change
	# We now have C000-FFFF ROM
	# 0400-7FFF single RAM block
	# This is much simpler and storage size simply isn't an issue
	dd if=../../fuzix.bin of=fuzixide.rom bs=1024 skip=48 count=16
	dd if=../../fuzix.bin of=fuzix.ide bs=1024 skip=1 count=31
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

	$(CROSS_LD) -b  -C 0xC000 -S 0x1A00 -f CSsLDBbX -o ../../fuzix-sdc.bin -m fuzix.tmpmap \
	crt0.o bootstrap_sdc.o commonmem.o coco2.o discard.o ../../mm/simple.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../dev/drivewire/drivewire.o ../../dev/devdw.o ../../dev/tinyide.o ../../dev/tinyide_discard.o ide.o \
	../../dev/tinydisk.o ../../dev/tinydisk_discard.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_exec.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o usermem.o ../../syscall_fs2.o \
	../../syscall_exec16.o devtty.o ../../vt.o video.o  ../../syscall_fs3.o \
	../../blk512.o ../../font/font8x8.o devsdc.o sdc.o ../../devinput.o devinput.o \
	/opt/fcc/lib/6809/lib6809.a
	dd if=../../fuzix-sdc.bin of=fuzixsdc.rom bs=1024 skip=48 count=16
	dd if=../../fuzix-sdc.bin of=fuzix.sdc bs=1024 skip=1 count=31
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix-sdc.map


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# We have 2048 blocks at the start which are the partition table then our
	# image blocks
	cp $(IMAGES)/disk.img $(IMAGES)/sd.img
	# Write the rest of the images to the disks
	dd if=fuzix.ide of=$(IMAGES)/disk.img bs=512 seek=1 conv=notrunc
	dd if=fuzix.sdc of=$(IMAGES)/sd.img bs=512 seek=1 conv=notrunc
	# Cartridge ROM
	cp fuzixide.rom $(IMAGES)/fuzixide.rom
	cp fuzixsdc.rom $(IMAGES)/fuzixsdc.rom
