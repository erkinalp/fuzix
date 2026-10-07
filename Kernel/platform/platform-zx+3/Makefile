CSRCS = devtty.c devices.c main.c
CDSRCS = discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c ../../dev/devfdc765.c ../../dev/tinysd.c
DDSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c
DZSRCS = ../../dev/zx/zxkeyboard.c ../../dev/zx/devinput.c ../../dev/zx/zxmmc.c
DDZSRCS =
ASRCS = crt0.S plus3.S zxvideo.S fdc765.S
ASRCS += tricks.S commonmem.S
AZSRCS = ../../dev/zx/zxmmc-spi.S ../../dev/zx/divide.S
NSRCS = ../../dev/net/net_w5x00.c

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
AZOBJS = $(patsubst ../../dev/zx/%.S,%.o, $(AZSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
DZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DZSRCS))
DDZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DDZSRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))
OBJS  = $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(DZOBJS) $(DDZOBJS) $(NOBJS) $(AZOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/zx/ -I../../dev/net

#CROSS_CC_SEG3 = -Tcommon

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $<

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $<

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $<

$(DDZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(AZOBJS): %.o: ../../dev/zx/%.S
	$(CROSS_AS) $(ASOPTS) $<

zxvideo.S: ../../dev/zx/video.S

clean:
	rm -f $(OBJS) *.o core *~ 
	rm -f loader.tmp loader.ihx loader.bin padding.bin disk.raw
	rm -rf fuzix.dsk

loader.bin: loader.S
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	# Extract the loader itself
	dd if=loader.tmp bs=512 skip=127 conv=sync | ../../tools/plus3boot >loader.bin

image:	loader.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF000 -f CLDBbXSs -o fuzix.bin \
	crt0.o commonmem.o plus3.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../vt.o \
	../../devinput.o ../../dev/zx/devinput.o ../../dev/zx/keyscan.o \
	devtty.o ../../dev/tinydisk.o \
	../../dev/tinydisk_discard.o ../../dev/tinysd.o \
	../../dev/tinysd_discard.o ../../dev/zx/zxmmc.o \
	../../dev/zx/zxmmc-spi.o ../../dev/zx/divide.o \
	../../dev/tinyide_discard.o ../../dev/tinyide.o \
	../../dev/net/net_w5x00.o fdc765.o ../../dev/devfdc765.o \
	 zxvideo.o ../../dev/zx/zxkeyboard.o ../../mm/bankfixed.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 <../../fuzix.map fuzix.bin ../../fuzix.bin
	# Padding to fill the virtual disk
	dd if=/dev/zero of=padding.bin bs=512 count=360
	# Make a disk image to work from
	dd if=../../fuzix.bin of=fuzix.bin bs=256 skip=1
	cat loader.bin fuzix.bin padding.bin >disk.raw
	# And generate a 40 track plus3 disk from it
	../../tools/raw2dsk disk.raw fuzix.dsk

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	cp fuzix.dsk $(IMAGES)/
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/hdfheader $(IMAGES)/disk.img > $(IMAGES)/emu-ide.hdf
