Z8K_GCC = /Users/paxia/Projects/gcc-z8k/build-z8k-coff/gcc
XGCC = $(Z8K_GCC)/xgcc -B$(Z8K_GCC)/
AS = z8k-coff-as
LD = z8k-coff-ld
COFF2AOUT = ../../../../Standalone/coff2aout

CFLAGS = -Os -msegmented -ffreestanding -nostdlib -fno-builtin -Wall

LDSCRIPT = \
	"OUTPUT_FORMAT(\"coff-z8k\") \
	OUTPUT_ARCH(z8001) \
	SECTIONS { \
	  .text 0 : { *(.text .text.*) } \
	  .data SIZEOF(.text) : { *(.data .rodata .rodata.*) } \
	  .bss SIZEOF(.text) + SIZEOF(.data) : { *(.bss) *(COMMON) } \
	}"

all: init.bin hello.bin

crt0.o: crt0.S
	$(AS) -z8001 -o $@ $<

syscalls.o: syscalls.S
	$(AS) -z8001 -o $@ $<

init.o: test/init.c
	$(XGCC) $(CFLAGS) -c -o $@ $<

INIT_OBJS = crt0.o init.o syscalls.o

init.merged.o: $(INIT_OBJS)
	$(LD) -m z8001 -r -T /dev/stdin -o $@ $(INIT_OBJS) <<< $(LDSCRIPT)

init.bin: init.merged.o $(COFF2AOUT)
	$(COFF2AOUT) -o $@ $<

hello.o: test/hello.c
	$(XGCC) $(CFLAGS) -c -o $@ $<

HELLO_OBJS = crt0.o hello.o syscalls.o

hello.merged.o: $(HELLO_OBJS)
	$(LD) -m z8001 -r -T /dev/stdin -o $@ $(HELLO_OBJS) <<< $(LDSCRIPT)

hello.bin: hello.merged.o $(COFF2AOUT)
	$(COFF2AOUT) -o $@ $<

$(COFF2AOUT): ../../../../Standalone/coff2aout.c
	$(CC) -Wall -O2 -o $@ $<

clean:
	rm -f *.o *.coff *.bin
