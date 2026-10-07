# Agon Light

The Agon Light, Olimex AgonLight2 and compatibles. An eZ80F92 at 18.432MHz
with 512K of external RAM, an ESP32 "VDP" for video and keyboard on UART0,
and a micro SD card on the eZ80 SPI.

FUZIX runs the eZ80 in Z80 mode and builds with the Z80 compiler. The few
eZ80 instructions needed are hand encoded.

Adapted from the 2063, ZRC and EZ-Retro ports.

## Supported

- 512K RAM: kernel plus up to seven 56K processes (no swap)
- VDP console in terminal mode (tty1)
- 100Hz timer from PRT0
- SD card (tinysd)

Tested on an AgonLight2 with MOS 3.0.2 and VDP 2.16.0.

## Memory map

The external RAM is banks 04-0B, selected by MBASE. RAM_ADDR_U is set to
match, so the 8K internal RAM is at E000-FFFF of the current bank and is
common memory.

Kernel (bank 04)
```
0000-00FF	Vectors, MOS header
0100-DFFF	Kernel, buffers, discard
E000-FFFF	Common
		FF00-FF5F IM2 vectors
```

User (banks 05-0B)
```
0000-00FF	Vectors
0100-DDFF	Process
DE00-DFFF	udata stash
E000-FFFF	Common
```

## Building

```
make TARGET=agon diskimage
```

Needs sfdisk and mtools. Images/agon/sdcard.img has a FAT partition with
fuzix.bin and an autoexec.txt to boot it, then the FUZIX root on hda2.

## Booting

Write sdcard.img to an SD card. MOS boots FUZIX from autoexec.txt, or by
hand with

```
load fuzix.bin
run
```

Press a key at the pause after the SD card is found to pick a different root
device.

To use an existing card, make partition 2 type 7E and at least 32MB, copy
filesys.img onto it and put fuzix.bin on the FAT partition.

The root .profile sets TERM=xterm, the closest match to the VDP terminal.

## TODO

- UART1 on the GPIO header and UEXT as tty2
- Use the eZ80 24bit block moves for fork and user copies
- Swap
- Use the RAM hidden behind common memory
- Set the time from the VDP clock
- VDP screen mode selection
- RTS flow control when the input queue fills
