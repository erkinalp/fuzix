CSRCS = devices.c main.c devinput.c

CDSRCS = discard.c

DSRCS =	../../dev/tinydisk.c ../../dev/tinysd.c
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c

ASRCS = crt0.S to8.S
ASRCS += tricks.S commonmem.S usermem.S

TSRCS = ../../dev/thomson/devfdc.c ../../dev/thomson/devtty.c
TASRCS = ../../dev/thomson/video-to8.S ../../dev/thomson/sdcard.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
TOBJS = $(patsubst ../../dev/thomson/%.c,%.o, $(TSRCS))
TAOBJS = $(patsubst ../../dev/thomson/%.S,%.o, $(TASRCS))
OBJS  = $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(TOBJS) $(TAOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/thomson/

all: $(OBJS)

export CROSS_CC_SEGD=-Tbuffers
export CROSS_CC_SEGI=-Tbuffers

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $<

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(TOBJS): %.o: ../../dev/thomson/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(TAOBJS): %.o: ../../dev/thomson/%.S
	$(CROSS_CC) $(CROSS_CCOPTS)  $< -o $*.o

$(AOBJS): %.o: %.S
	$(CROSS_CC) $(CROSS_CCOPTS) $< -o $*.o

clean:
	rm -f *.o *~ boot.bin boot.tmp boot.tmp2 fuzix.bin fuzix.img fuzix.tmp 

boot.bin: boot.S ../../tools/bless-to8
	as6809 boot.S
	ld6809 -b -o boot.tmp boot.o
	dd bs=256 skip=98 count=1 < boot.tmp | ../../tools/bless-to8 >boot.bin

image: boot.bin
	$(CROSS_LD) -C 4 -X 0x6100 -D 0xA000 -f CSsXDBLb -b -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o commonmem.o \
	to8.o discard.o ../../mm/bankfixed.o usermem.o ../../mm/memalloc_none.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../dev/tinydisk.o ../../dev/tinysd.o \
	sdcard.o ../../dev/thomson/devtty.o video-to8.o \
	../../dev/tinydisk_discard.o ../../dev/tinysd_discard.o \
	../../dev/thomson/devfdc.o devinput.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o ../../blk512.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	../../vt.o ../../syscall_fs3.o ../../syscall_exec.o \
	../../devinput.o /opt/fcc/lib/6809/lib6809.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

	# 320K disk image
	dd if=/dev/zero of=fuzix.bin bs=1024 count=320
	# The disk image starts with the bootblock
	dd if=boot.bin of=fuzix.bin bs=256 conv=notrunc
	# A000-DFFF
	dd if=../../fuzix.bin of=fuzix.bin bs=256 seek=1 skip=160 count=64 conv=notrunc
	# 0000-3FFF
	dd if=../../fuzix.bin of=fuzix.bin bs=256 seek=65 count=64 conv=notrunc
	# 6400-9FFF
	dd if=../../fuzix.bin of=fuzix.bin bs=256 seek=129 skip=100 count=60 conv=notrunc
	# 4000-5FFF
	dd if=../../fuzix.bin of=fuzix.bin bs=256 seek=189 skip=64 count=32 conv=notrunc
	# And done.

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Write a boot floppy
	cp fuzix.bin $(IMAGES)/boot.fd
