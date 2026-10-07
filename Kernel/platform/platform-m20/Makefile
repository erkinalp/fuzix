
CSRCS = devtty.c devhd.c
CSRCS += devices.c main.c libc.c

ASRCS = m20.S crt0.S
ASRCS += tricks.S

COBJS = $(CSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.S=.o)
OBJS  = $(COBJS) $(AOBJS)

Z8KAS = z8k-coff-as -z8001
Z8KOCP = z8k-coff-objcopy

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o fuzix.bin fuzix.text.bin fuzix.data.bin bootloader.o bootloader.coff bootloader.bin core *~

image:
	$(CROSS_LD) -m z8001 -o fuzix.bin -T fuzix.ld \
	m20.o ../../start.o ../../version.o ../../cpu-z8000/lowlevel-z8000.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../flat.o \
	../../blk512.o ../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o \
	../../syscall_fs3.o ../../syscall_exec32.o ../../syscall_exec.o \
	../../cpu-z8000/usermem_std-z8000.o devtty.o devhd.o libc.o ../../malloc.o \
	> ../../fuzix.map
	$(Z8KOCP) -j .text -O binary fuzix.bin fuzix.text.bin
	$(Z8KOCP) -j .data -O binary fuzix.bin fuzix.data.bin

Z8KLD = z8k-coff-ld

bootloader.bin: bootloader.s
	$(Z8KAS) -o bootloader.o $<
	$(Z8KLD) -m z8001 -Ttext 0 -o bootloader.coff bootloader.o
	$(Z8KOCP) -O binary bootloader.coff $@

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: bootloader.bin
	mkdir -p $(IMAGES)
	cd $(FUZIX_ROOT)/Standalone/filesystem-src && \
	perl build-filesystem-ng -x \
		-f $(IMAGES)/filesys.img \
		-g 256 16384 \
		-p basefs -p util-mini -p util -p V7-sh -p V7-cmd-micro
	python3 mkm20hd.py bootloader.bin fuzix.text.bin fuzix.data.bin $(IMAGES)/hd.img $(IMAGES)/filesys.img
