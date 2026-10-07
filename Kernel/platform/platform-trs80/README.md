# TRS80 Model 4/4D/4P

## Base Systems

- Tandy TRS80 Model 4 (including 4D and gate array models) 128K
- Tandy TRS80 Model 4P 128K

## Supported Hardware

- Floppy Disk (required for boot at this point)
- Hard Disk (Tandy or compatible including things like FreHD)
- Alpha Technology Style Joystick
- Tandy Hi-res card (graphics use only)
- Huffman style memory banking on port 0x94
- Anitek Hypermem (not yet properly tested)
- Anitek Megamem (as a RAMdisc and swap)

## To Do

- 4P and modified rom model 4 hard disk boot
- Microlabs Grafyx reporting for graphics use only
- Alpha technology supermem
- FreHD specific features
- Split base 128K kernel from a thunked kernel for the memory bank cards
- Supermem ?

## Unsupported

- XLR8R/4ccelerator - really deserves its own Z180 mode port
- M3SE except as far as compatibility goes

## Installation

make diskimage
Set up hard1-0 as a hard disk image on a FreHD
Put the relevant boot.jv3 disk on the FreHD and use the FredHD apps to make
a floppy disk of it.

At the boot prompt select 2 (hda1 is the boot zone, hda2 is the file system)

## Emulator Notes

Copy boot.jv3 to disk4p-0 or disk4-0 and use hard4p-0 from the emulator with xtrs or a
FredHD.

You will still need a boot floppy but you can make those using a FreHD or
other tools from the JV3
