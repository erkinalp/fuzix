CSRCS = devices.c main.c devtty.c devinput.c

CDSRCS = discard.c

DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c ../../dev/ds1302.c ../../dev/tinysd.c
DASRCS = ../../dev/ds1302_6809.s
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c ../../dev/tinysd_discard.c

ASRCS = crt0.s rcbus-6809.s ide.s sdcard.s
ASRCS += tricks.s commonmem.s mem-rcbus.s 

COBJS = $(CSRCS:.c=$(BINEXT))
CDOBJS = $(CDSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.s=$(BINEXT))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.s,%.o, $(DASRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(DAOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)

$(COBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(CDOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(DDOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(AOBJS): %$(BINEXT): %.s
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

$(DAOBJS): %$(BINEXT): ../../dev/%.s
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o *~

# Code at 0x0000 then segments follow until we hit the commondata (F200) and then
# the common code follows that
image:
	$(CROSS_LD) -b -C 0x0 -X 0xC300 -8 0xF200 -Z 0x00 -f CLDBbXsS -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o commonmem.o mem-rcbus.o \
	rcbus-6809.o ../../mm/bank16k.o ../../dev/ds1302.o ds1302_6809.o \
	../../devinput.o devinput.o ../../mm/memalloc_none.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o ../../blk512.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_exec16.o ../../syscall_exec.o devtty.o \
	../../dev/tinydisk.o ../../dev/tinyide.o ide.o ../../dev/tinysd.o sdcard.o \
	../../dev/tinydisk_discard.o ../../dev/tinyide_discard.o discard.o \
	../../dev/ds1302_discard.o ../../dev/tinysd_discard.o \
	/opt/fcc/lib/6809/lib6809.a
	# Pack the common down lower
	dd if=../../fuzix.bin bs=61440 skip=1 >fuzix.high
	# Packed at E000
	dd if=fuzix.high of=../../fuzix.bin bs=57344 seek=1
	#rm fuzix.high
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the bootstrap loader
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=../../fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
