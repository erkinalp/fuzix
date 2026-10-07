ASRCS = crt0.S z180.S commonmem.S rcbus-z180.S monitor.S ide.S
CSRCS += devices.c main.c devtty.c spi.c i2c.c wiznet.c #devenc28j60.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c ../../dev/tinysd_discard.c
DISCARD_DSRCS += ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/ds1302.c ../../dev/tinydisk.c ../../dev/ch375.c
DSRCS += ../../dev/tinysd.c ../../dev/devi2c.c ../../dev/i2c_bitbang.c
DASRCS = ../../dev/ds1302_rcbusu_z180.S #../../dev/z80softspi.S
NSRCS = ../../dev/net/net_w5x00.c
#NSRCS = ../../dev/net/enc28j60.c ../../dev/net/net_native.c

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(DAOBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $<

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) core *~ boot-romwbw.tmp boot-romwbw.bin
	rm -f loader.bin loader.tmp boot-romwbw.bin boot-romwbw.tmp

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

boot-romwbw.bin: boot-romwbw.S
	fcc -mz80 -c boot-romwbw.S
	# This makes us a binary from physical 0
	ldz80 -b boot-romwbw.o -o boot-romwbw.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot-romwbw.tmp of=boot-romwbw.bin bs=512 conv=sync count=2 skip=120

image: boot-romwbw.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF400 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o z180.o rcbus-z180.o main.o devices.o discard.o \
	devtty.o spi.o ../../dev/tinyide.o ../../dev/tinyide_discard.o \
	ide.o ../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinysd.o ../../dev/tinysd_discard.o \
	monitor.o ../../dev/ds1302.o ../../dev/ds1302_discard.o \
	../../dev/ds1302_rcbusu_z180.o \
	../../dev/i2c_bitbang.o ../../dev/devi2c.o i2c.o \
	../../dev/net/net_w5x00.o wiznet.o ../../dev/ch375.o \
	../../libfuzix.a ../../libfuzix.a /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map
	cat boot-romwbw.bin >fuzix.romwbw
	dd if=/dev/zero bs=256 count=1 >>fuzix.romwbw
	dd if=fuzix.bin bs=256 skip=1  >>fuzix.romwbw

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.romwbw of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
