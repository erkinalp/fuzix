CSRCS = devices.c main.c devinput.c

C3SRCS =

CDSRCS = discard.c

DSRCS =	../../dev/tinydisk.c ../../dev/tinysd.c
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c

ASRCS = crt0.S to770.S sdcard.S lowlevel.S bankswitch.S
ASRCS += tricks.S commonmem.S usermem.S

TSRCS = ../../dev/thomson/devfdc.c ../../dev/thomson/devtty.c
TASRCS = ../../dev/thomson/video-to770.S

COBJS = $(CSRCS:.c=.o)
C3OBJS = $(C3SRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
TOBJS = $(patsubst ../../dev/thomson/%.c,%.o, $(TSRCS))
TAOBJS = $(patsubst ../../dev/thomson/%.S,%.o, $(TASRCS))
OBJS  = $(COBJS) $(C3OBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(TOBJS) $(TAOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/thomson/

all: $(OBJS)

export CROSS_CC_SEGD=-Tdiscard
export CROSS_CC_SEGI=-Toverlay1

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(C3OBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGI) -c $<

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $<

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(TOBJS): %.o: ../../dev/thomson/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(TAOBJS): %.o: ../../dev/thomson/%.S
	$(CROSS_AS) $(ASOPTS)  $< -o $*.o

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o *~ boot.bin boot.tmp boot.tmp2 fuzix.bin fuzix.img fuzix.tmp 

boot.bin: boot.S ../../tools/bless-to8
	fcc -m6809 -c boot.S
	ld6809 -b boot.o -o boot.tmp
	dd bs=256 skip=98 count=1 < boot.tmp | ../../tools/bless-to8 >boot.bin

image: boot.bin
	$(CROSS_LD) -b -O 0 -f CSsDLBbX -C 0xA000 \
	-o ../../fuzix.bin -m fuzix.tmpmap -R fuzix.relocs \
	crt0.o commonmem.o bankswitch.o \
	to770.o discard.o ../../mm/bankfixed.o usermem.o ../../mm/memalloc_none.o \
	../../start.o ../../version.o lowlevel.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../dev/tinydisk.o ../../dev/tinysd.o sdcard.o \
	../../dev/tinydisk_discard.o ../../dev/tinysd_discard.o \
	../../dev/thomson/devfdc.o devinput.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o ../../blk512.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	../../dev/thomson/devtty.o ../../vt.o \
	video-to770.o ../../syscall_fs3.o ../../syscall_exec.o \
	../../devinput.o /opt/fcc/lib/6809/lib6809.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	bankman ../../fuzix.bin fuzix.tmpmap fuzix.relocs 6809
# Build the image
	# Copy 16K from overlay1/2/3 into the cartridge banks 0-2
	dd if=../../fuzix.bin of=fuzix.memo7 bs=16384 skip=4 count=1
	dd if=../../fuzix.bin of=fuzix.memo7 bs=16384 skip=8 seek=1 count=1
	dd if=../../fuzix.bin of=fuzix.memo7 bs=16384 skip=12 seek=2 count=1
	# Copy the upper bank into cartridge bank 3
	dd if=../../fuzix.bin of=fuzix.memo7 bs=1024 skip=40 seek=3 count=16
	# Now the bootstrap and shared space 6100-6300
	dd if=../../fuzix.bin of=fuziz.memo7 bs=256 skip=97 seek=62 count=2
	# Our cartridge now contains
	# 0000-3DFF Overlay1, 3E00-3FFF copy of the 6100-62FF area
	# 4000-7FFF Overlay2
	# 8000-BFFF Overlay3
	# C000-FFFF Kernel A000-DFFF
	
IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	cp fuzix.memo7 $(IMAGES)
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
