# Notes for the Video Genie EG 64.3 / Lubomir Soft Banker

## The Hardware

The two have the same interface (and may well be the same logic). They add
an I/O port at 0xC0 which controls how memory is mapped

Port 0xC0

| Bit   | State | Meaning          |
|:------|:------|:------------------|
| Bit 7 | Clear | Writes to 0000-37DF are ROM|
|       | Set   | Writes to 0000-37DF are RAM|
| Bit 6 | Clear | Reads from 0000-37DF are ROM|
|       | Set   | Reads from 0000-37DF are RAM|
| Bit 5 | Clear | I/O is visible at 37E0-3FFF|
|       | Set   | RAM is visible at 37E0-3FFF|
| Bit 4 | Clear | High 32K is from RAM|
|       | Set   | High 32K is from the expansion box|

## Bugs

## To Add

Can we do lower case on UDG card if not on base machine ?

## Memory Map

0000-5FFF	Small parts of the kernel, video driver and data, common, constants initialized data and buffers
6000-7FFF	Always user space (used for discardable code at boot)
8000-FFFF	Banked kernel or user

We don't load 3800-3FFF or 4000-41FF. The latter is easy to fix the former
is quite tricky, so we need to load BSS space there if we use it.

## Notes

Note that there appears to have been a different 'EG MBA' memory banking
adapter that only allows mapping of the 64K over the ROM via a different
port. This is not supported.

Floppy boot requires a single density disk. The Level II ROM reads
disk 0 side 0 track 0 sector 0 (TRS80 disks are 0 offset sector count)
into 4200-42FF and then does a JP 4200	(stack is around 407D)

## Other Targets TODO

EACA GeniePlus EG 3200 - up to 8 banks mapping lower or upper 32K of bank to machine
low 32K		sys_byte bit 0 unmaps rom 1 unmaps video 2 unmaps extra
		video for 80x24 else memory or banked memory
		bank base 1-7 by genieplus card, low 3 bits, bit 4 selects
		upper/lower 32K bank of the 64K card slot, maps to low 32K
		0x28 bank reg ?
		0xFA init out (enables and sets sys byte)

		0x48-0x4F hard disk
		0x80-0x83 HRG
		0xE0 RTC
		0xF5 bit 0 inverse vid
		0xF6/F7 crtc
		0xFA sys byte
		0xFD printer


Holmes VID80 (M3) - 48K extended RAM between 0000-BFFF enabled via a bit,
		sys_byte bit 6 - low 48K is expansion
                bit 1 video F800-FFFF
                bit 4 = 0, bit 0=1 ROM
		bit 3 video at usual spot
                bit 1 = 0 keyboard at usual
                bit 0 = 0 low 4K vid80 ROM
		0x3C/D - 6845
		0x3F write enables and sets sys byte
		0x5F sprinter III speed up

video at 0xF8000-FFFF option
ROM can be paged out

The LNW80-2 has a 96K arrangement allowing 64K RAM with a 32K overlay and
supported CP/M so might also be suitable with a bit of work. The LNW80 also
has a rather complicated extended video space for 80 columns.

Banking on the LNW80 is

0x1F	D0=1		Swap low 16K with top 16K
        D1=1		0-16K as RAM except MMIO
	D2=1		Ints off
	D3=0
	D4=1		Replace MMIO with RAM
	D5=1		Disable additional 32K banked in RAM (ie 16K mode)
	D6=1		Bank in additional 32K
	D7=1		Write protect low 12K (ROM emulation)

So 1F=3
	0-0xF6FF	RAM
	F700-FFFF	I/O and a small RAM window (F900-FBFF)

and D6=1 switches between the two banks


0x37E4(R) - Apple style joystick on bits 2-7 ( 2-7 in order F1 F2 X1 X2 Y2 Y1)

37DE/F serial
37E8 printer

Video RAM on LNW80

bitmap mode (when mapped in low)	0xFE bit D3 = 1 graphics
	00 RRRR LLLL CCCC	row line char (so top of each char first
				and interleaved like spectrum) 6bit wide
	00111RRLLLLrrCCCC	right side bit for 80 col
				RR=low 2 bits of rom, rr = high 2 bits of row
text
	3C00-3FFF		as TRS80m1

Colour mode options for ntsc output

Modes
0		Lores 128x48 mixed with text (TRS80)
1		Hires 480x192 mixed with lores
2		Lores 128x192 in 8 colours
3		Hires 38x192 with 128x16 colour mapping blocks (RGB monitor only)


UART at 0xE8-EB (modem status, config jumpers, status, rx R)
                (reset, -, control, tx W) TR1602B


0xE9 BRG  4bit codes 50/75/110/134.5/150/300/600/1200/1800/2000/2400/3600/
		     4800 7200 9600 19200
		TX << 4 | RX

0x95	Graphcis page display D7/D6  accessed D5/D4 - optional

0xFE	0: inverse video 1-2 display mode (0-2) 3 graphics enable low 16K
        4-6: background colour 7: set inverse char mode D5 bit 2 turns
	on/off char inverse video

0x95:	0-1 must be zero, 2 inverse char on/off 3 mbz 4-78 pages


Speedmaster ? - 0x7E tcs_ram192b_out
0xFE sys byte
0xFF bit 3 modesel

S80Z 0xD2 - banking, 0xD0/D1 6845