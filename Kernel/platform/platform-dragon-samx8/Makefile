### Fuzix build rules for Dragon + SAMx8 platform

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Common platform sources

# There's no need to break out assembly sources by segment, as that information
# can be specified in the source file.
#
# .S files are preprocessed with cc -E into .s files, which are then assembled.
# This is typically only needed when conditional macros or file inclusion are
# used.  Be aware that conditional macros apply during the preprocessing step
# and NOT during the assembly.

# Initial assembly sources (linked first)
INIT_ASSRCS = crt0.S
INIT_ASRCS = ../platform-dragon-nx32/commonmem.s

# Assembly sources
ASSRCS = dragon-samx8.S mem-samx8.S tricks.S usermem-samx8.S
ASRCS =

# C sources
CSRCS = devices.c main.c devtty.c devlpr.c \
	../platform-dragon-nx32/devfd.c ../platform-dragon-nx32/devinput.c \
	../platform-dragon-nx32/libc.c

# C sources for discard segment
CDSRCS = discard.c devices-discard.c

# Video-related sources.  Anything that needs the video memory mapped must
# either sit in common or BELOW 0xC000, so we consider them separately to give
# us the flexibility to position them in the link order.
VSRCS = vc.c
VASSRCS = multihead.S vc-samx8.S video.S

# Specific device support
ASRCS += ../platform-dragon-nx32/floppy.s
ASRCS += mpi.s
ASRCS += joystick.s

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Targets

DISKIMAGES = diskimage-ddos

ifndef SUBTARGET
SUBTARGET = sdc
endif

# Real hardware - CoCoSDC
ifeq ($(SUBTARGET),sdc)
ifndef WANT_COCOSDC
WANT_COCOSDC = yes
endif
DISKIMAGES += diskimage-sdc
endif

# Real hardware - IDE (untested)
ifeq ($(SUBTARGET),ide)
ifndef WANT_COCOIDE
WANT_COCOIDE = yes
endif
ifndef WANT_DRIVEWIRE
WANT_DRIVEWIRE = yes
endif
DISKIMAGES += diskimage-ide
endif

# Emulation - IDE and becker port
ifeq ($(SUBTARGET),emu)
ifndef WANT_COCOIDE
WANT_COCOIDE = no
endif
ifndef WANT_DRIVEWIRE
WANT_DRIVEWIRE = yes
endif
ifndef WANT_BECKER
WANT_BECKER = yes
endif
endif

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Driver sources

# CoCoSDC support (tinydisk)

ifeq ($(WANT_COCOSDC),yes)
CSRCS += ../platform-coco3/devsdc.c
CDSRCS += ../platform-coco3/devsdc-discard.c
ASSRCS += ../platform-coco3/sdc.S
CROSS_CCOPTS += -DCONFIG_COCOSDC
WANT_TINYDISK = yes
FZLOAD09_DEVICE ?= cocosdc
endif

# IDE support (tinydisk)

ifeq ($(WANT_COCOIDE),yes)
ASSRCS += ide.S
CSRCS += ../../dev/tinyide.c
CDSRCS += ../../dev/tinyide_discard.c
CROSS_CCOPTS += -DCONFIG_TD_IDE -DCONFIG_COCOIDE
WANT_TINYDISK = yes
endif

# Tinydisk support

ifeq ($(WANT_TINYDISK),yes)
ASRCS += tinydisk-samx8.s
CSRCS += ../../dev/tinydisk.c
CDSRCS += ../../dev/tinydisk_discard.c
CROSS_CCOPTS += -DCONFIG_TINYDISK
endif

# DriveWire support

ifeq ($(WANT_DRIVEWIRE),yes)
ASSRCS += ../../dev/drivewire/drivewire.S
CSRCS += ../platform-dragon-nx32/ttydw.c
CSRCS += ../../dev/devdw.c
CROSS_CCOPTS += -DCONFIG_DRIVEWIRE
endif

FZLOAD09_DEVICE ?= dragondos

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Build rules

ASRCS += $(ASSRCS:.S=.s)
VASRCS += $(VASSRCS:.S=.s)

INIT_AOBJS = $(INIT_ASSRCS:.S=.o) $(INIT_ASRCS:.s=.o)
AOBJS = $(ASRCS:.s=.o)
COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
VOBJS = $(VSRCS:.c=.o)
VAOBJS = $(VASRCS:.s=.o)
# Everything we build here except INIT_AOBJS:
OBJS  = $(VAOBJS) $(VOBJS) $(COBJS) $(AOBJS) $(CDOBJS)

CLEAN = $(INIT_AOBJS) $(OBJS)
CLEAN += $(INIT_ASSRCS:.S=.s) $(ASSRCS:.S=.s)

# fcc debugging
CLEAN += $(CSRCS:.c=.s) $(CSRCS:.c=.#) $(CSRCS:.c=.%) $(CSRCS:.c=.@) $(CSRCS:.c=.^)
CLEAN += $(CDSRCS:.c=.s) $(CDSRCS:.c=.#) $(CDSRCS:.c=.%) $(CDSRCS:.c=.@) $(CDSRCS:.c=.^)
CLEAN += $(VSRCS:.c=.s) $(VSRCS:.c=.#) $(VSRCS:.c=.%) $(VSRCS:.c=.@) $(VSRCS:.c=.^)

CROSS_CCOPTS += -I$(FUZIX_ROOT)/Kernel/dev

.PHONY: all
all: $(INIT_AOBJS) $(OBJS)

$(INIT_AOBJS) $(AOBJS) $(VAOBJS): %.o: %.s
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(VOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_VIDEO) -c $<

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Special build rules

../../dev/drivewire/drivewire.s: ../../dev/drivewire/dw-6809.def
../../dev/drivewire/drivewire.s: ../../dev/drivewire/dwread-6809.s
../../dev/drivewire/drivewire.s: ../../dev/drivewire/dwwrite-6809.s

../../dev/drivewire/drivewire.s: ../../dev/drivewire/drivewire.S
	$(CC) -DBECKER -DBCKSTAT=0xff49 -DBCKPORT=0xff4a -E -o $@ $<

../platform-coco3/sdc.s: ../platform-coco3/sdc.S
	$(CC) -DCONFIG_SDC_DRAGONDOS -E -o $@ $<

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Kernel image

# Base
KOBJS = ../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o

# Memory
KOBJS += ../../mm/bank16k.o ../../mm/memalloc_none.o ../../mm.o \
	../../process.o ../../swap.o ../../usermem.o

# IO
# Note: we put vt.o first because it exports vtattr, which needs to reside
# below the mapped-in screen (at 0xC000) while we're updating it.
KOBJS += ../../vt.o ../../devinput.o ../../devio.o ../../devsys.o ../../kdata.o \
	../../timer.o ../../tty.o ../../font/font8x8.o

# The rest (filesystem, syscalls)
KOBJS += ../../blk512.o ../../filesys.o ../../inode.o \
	../../syscall_exec.o ../../syscall_exec16.o ../../syscall_fs.o \
	../../syscall_fs2.o ../../syscall_fs3.o ../../syscall_other.o \
	../../syscall_proc.o

../../fuzix.bin: $(INIT_AOBJS) $(KOBJS) $(OBJS)
	$(CROSS_LD) -b -C 0 -8 0xF000 -Z 0x00 -f CLDBbXsS \
		-o $@ -m fuzix.tmpmap \
		$(INIT_AOBJS) $(KOBJS) $(OBJS) \
		/opt/fcc/lib/6809/lib6809.a || { rm -f $@ && exit 1; }
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

CLEAN += fuzix.tmpmap

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## fzload09 boot loader

FZLOAD09_ASRCS = fzload09.s

ifeq ($(FZLOAD09_FORMAT),dzip)
FZLOAD09_ASRCS += fzload09-dzip.s
else
FZLOAD09_ASRCS += fzload09-raw.s
endif

ifeq ($(FZLOAD09_DEVICE),dragondos)
FZLOAD09_ASRCS += fzload09-dragondos.s
else ifeq ($(FZLOAD09_DEVICE),cocosdc)
FZLOAD09_ASRCS += fzload09-cocosdc.s
else
$(error No FZLOAD09_DEVICE specified)
endif

FZLOAD09_AOBJS = $(FZLOAD09_ASRCS:.s=.o)

fzload09.bin: $(FZLOAD09_AOBJS)
	ld6809 -b -m $(@:.bin=.map) -C 0x2600 -f CDSLsX -o $@ $(FZLOAD09_AOBJS)

$(FZLOAD09_AOBJS): %.o: %.s
	fcc -m6809 -c -o $@ $<

ifeq ($(FZLOAD09_FORMAT),dzip)
fzload09.img: fzload09.bin ../../fuzix.bin
	dd if=fzload09.bin of=$@ bs=256 skip=38 status=none
	dd if=../../fuzix.bin bs=256 count=64 status=none | dzip -c >> $@
	dd if=../../fuzix.bin bs=256 skip=64 count=64 status=none | dzip -c >> $@
	dd if=../../fuzix.bin bs=256 skip=128 count=64 status=none | dzip -c >> $@
	dd if=../../fuzix.bin bs=256 skip=192 count=64 status=none | dzip -c >> $@
else
fzload09.img: fzload09.bin ../../fuzix.bin
	dd if=fzload09.bin of=$@ bs=256 skip=38 status=none
	dd if=../../fuzix.bin bs=256 count=64 status=none >> $@
	dd if=../../fuzix.bin bs=256 skip=64 count=64 status=none >> $@
	dd if=../../fuzix.bin bs=256 skip=128 count=64 status=none >> $@
	dd if=../../fuzix.bin bs=256 skip=192 count=64 status=none >> $@
endif

fzload09.dsk: fzload09.img
	dd if=/dev/zero of=$@ bs=256 count=720 conv=sync status=none
	dd if=$< of=$@ bs=256 seek=2 conv=sync,notrunc status=none

CLEAN += fzload09.bin fzload09.img fzload09.dsk

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Disk images

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

.PHONY: image
image: ../../fuzix.bin

.PHONY: diskimage-sdc
diskimage-sdc: fzload09.dsk
	# Make a blank disk image
	dd if=/dev/zero of=$(IMAGES)/fuzix-sdc.img bs=512 count=39360 status=none
	# Copy boot floppy image to the very beginning
	dd if=fzload09.dsk of=$(IMAGES)/fuzix-sdc.img bs=256 conv=sync,notrunc status=none
	# Add partition table (overwrite first 512 bytes of boot floppy image)
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/fuzix-sdc.img bs=512 count=1 conv=sync,notrunc status=none
	# Add the filesystem
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/fuzix-sdc.img bs=512 seek=2048 conv=notrunc status=none

.PHONY: diskimage-ide
diskimage-ide:
	# Make a blank disk image
	dd if=/dev/zero of=$(IMAGES)/fuzix-ide.img bs=512 count=39360 status=none
	# Add partition table (overwrite first 512 bytes of boot floppy image)
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/fuzix-ide.img bs=512 count=1 conv=sync,notrunc status=none
	# Add the filesystem
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/fuzix-ide.img bs=512 seek=2048 conv=notrunc status=none

.PHONY: diskimage-ddos
diskimage-ddos: fzload09.dsk
	# Just copy it
	dd if=$< of=$(IMAGES)/fuzix-ddos.DSK bs=256 conv=sync status=none

.PHONY: diskimage
diskimage: $(DISKIMAGES)

## - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Tidy up

.PHONY: clean
clean:
	rm -f $(CLEAN) core *~
