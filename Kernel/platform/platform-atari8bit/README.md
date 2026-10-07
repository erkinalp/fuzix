# Atari 8bit 128K machine

Strictly some initial research into what is possible and to debug the
bankman overlay support for 6502

Current model is

0000-00FF	ZP, part kernel part user process. Easy enough
0100-01FF	Stack. Shared between kernel and user.
0200-3FFF	User
4000-7FFF	Main memory is video and kernel overlay4. Banks hold
		user page and 3 more kernel pages. CPU accesses pages
		ANTIC is locked to the main memory page
8000-BFFF	User
C000-D7FF	Kernel data/code/common
D800-DFFF	I/O
E000-FFFF	Kernel data/code/common

Main RAM (compiler segment overlay4) is carefully laid out as

4000		Video buffer
43C0		Display List
43E0		Spare
4400		Font
4800		Buffers
????		Code for overlay 4

Because we can't point antic and the cpu at different ext banks we need to
keep the video in main ram so we can point the CPU all over the place. In
theory at some point once we've got something believable we can also
add more video space to the overlay4 segment if there is room to support
other video modes


## Mysteries
- How to load and boot this lot
- What to do about that the single unbankable ZP and stack

## In Progress
- Test bank switching functions
- Get bankman working with 6502 and producing plausible output
- Research hard disk I/O options

ZP we can handle between the process and kernel by splitting the allocation.
Need a special disk loader for ZP for swap that only stores some of the
stack so we have a bit of space for swap (say top 32 bytes with careful
management)

S is a real problem. User space is fine, syscall is fine as it will use the
same stack. Might need an Apple like "stack is a bit deep copy/fix/replace"
helper but we can do that fine.

The problems are context switches and swapping

Possible option
- Custom 'read page 0' routine in disk swap driver

Load 00-EF skip F0-FF as workspace for swapper asm
Load 100-1BF as ustack and kstack. preserve 1C0-1FF (maybe less) as swap
stack. We'd still have the separate C swap and main stacks too

So something like

```
next1:
	lda	diskdata
	sta	(@swapptr),y
	iny
	cpy	#0xF0
	bne	next1
disc1	lda	diskdata
	iny
	bne	disc1
	inc	@swapptr+1
next2:	lda	diskdata
	sta	(@swapptr),y
	iny
	cpy	#0xC0
	bne	next2
disc2	lda	diskdata
	iny
	bne	disc2
```

With a big RAM card we can use the extra pages of extra RAM as swap as we've
got only the 16K window but it would be more optimal to copy 32K and treat
is as banked as that cuts our copy down by 16K
	
Early systems have fixed ROM D800-FFFF and nothing C000-CFFF but also no
parallel bus so afaik no sensibly fast disk I/O ? For RAMBO style banking
if we wanted to cover it we'd also have to make sure we put constant data
in CF00-CFFF if present and also 0F00-0FFF. The former isn't hard but the
latter could in theory become data with a tiny user app so might need some
magic tricks to load tiny binaries at higher addresses.



## Loader Notes

Need to sort out turning raw bits into an ATR or XFD or similar or whatever
the emulator can be fed.

Boot sector is

00: boot flag mus tbe 0
01: sectors to load
02-03: address including header bytes to load (this stuff included)
04-05: execution address
06+: run me

Usually load at 0700

If we stick discard at 0x1000 or higher that lets us load a bootstrap loader
fairly easily. We then need to figure out where to put all the bits

We have something like this when our boot runs

0000-06FF	Various OS things ZP and stack etc (80-FF our ZP space)
0700-0FFF	Our loader
1000-3FFF	We can load stuff as part of loader
4000-7FFF	Ditto for main
8000-BFFF	May be able to load directly unclear
C000-FFFF	All owned by system,

So we would need to then load

alt 4000-7FFF	3 banks of
Most of C000-FFFF

obvious approach would be to load C000-FFFF bits into the user paged bank

So we'd

OS Load	0700-BFFF (if we can get that far)
Load three alt banks
Kill interrupts
Take over
Move 8000-BFFF into C000-FFFF except for I/O window

Disk I/O for boot

	DAUX1/2		low/hi of sector number
	DCOMND		'R' (Read)
	DBUFLO/HI	Address
	JSR		DSKINV
	BP		OK

0300	DCB
0301	DUNIT		(1 for dev 0)
0302	DCOMND
0303	DSTATS		return of op
0304	DBUF.W
0306	DTIMELO.B	seconds
0308	DBYT		count (not needed ?)
030A	DAUX1		cmd aux bytes	} sector ID for "R"
030B	DAUX2		""		}

Can we generate an emulator save state directly for faster debug cycles ?

Are there any suitable cartridge formats we can abuse for testing cycles

D5xx cartridge switching

8000-9FFF, maybe A000-BFFF mapping driven by cartridge

Options looking useful
ATRAX	128K	A000-BFFF	bits 0-3 control bank bit 7 disables cart
		responds only to D5E/Fx
		set bit 3 of x and state becomes bits 3/2
		clear bit 3 and state is b0bbb for 16 banks with the bank
		num inverted

		writitng to 0x8-0F sets the state to bits 3/2
		if the state bits are 10 the piggback cart enables
		if its 11 they disable

so can load off it then stuff IDE into piggyback

		