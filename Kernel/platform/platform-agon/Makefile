ASRCS = crt0.S commonmem.S agon.S tricks.S sd.S
CSRCS = devices.c main.c devtty.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinysd.c

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS)

CROSS_CCOPTS += -I../../dev/

JUNK = *.lst *.asm *.sym *.rst *.s *.\^ *.\# *.\% *.\@

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) $(JUNK) core *~ fuzix.bin fuzix.tmpmap

# MOS loads us at 0x040000. crt0 unpacks common and discard
image:
	$(CROSS_LD) -b -C 0x0000 -X 0xD000 -S 0xE000 -f CLDBbXSs -o fuzix.bin \
	crt0.o commonmem.o agon.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o tricks.o \
	main.o discard.o devtty.o devices.o sd.o \
	../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../mm/bankfixed.o ../../devsys.o \
	../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinysd.o ../../dev/tinysd_discard.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap | sort -n | cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 <../../fuzix.map fuzix.bin ../../fuzix.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# SD card with a MOS FAT partition then the FUZIX root
	rm -f $(IMAGES)/sdcard.img
	dd if=/dev/zero of=$(IMAGES)/sdcard.img bs=1M count=48
	sfdisk $(IMAGES)/sdcard.img < diskimage.sfdisk
	# Kernel and autoexec.txt to boot it on the FAT partition
	mformat -i $(IMAGES)/sdcard.img@@1M -v AGON ::
	mcopy -i $(IMAGES)/sdcard.img@@1M ../../fuzix.bin ::fuzix.bin
	mcopy -i $(IMAGES)/sdcard.img@@1M autoexec.txt ::autoexec.txt
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/sdcard.img bs=512 seek=32768 conv=notrunc
	cp ../../fuzix.bin $(IMAGES)
