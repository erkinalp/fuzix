# Fuzix for Bill Shen's MicroZ

The MicroZ is the follow up to the Micro80. It uses the Z84C15 in the same
way but because it has 64K of EPROM mappable not the 16K limit on the
Micro80 we can actually run from ROM.

## Supported Hardware

- MicroZ
- Onboard CF adapter
- Onboard SIO

## Memory Mapping

The hardware is wired so that the ROM is enably by CS0 low but unusually the
second CS line is wired to A16 on the 128K RAM. This allows the use of the
CSBR and MCR registers to place either RAM bank in the low or high area or
to map ROM space.

Our map is thus

0000-0FFF	Common code (ROM), literals (ROM). Must end below 0FFF
1000-CFFF	Continued kernel code | User 0 | User 1
D000-FDFF	UData, common data, data, bss for kernel
FE00-FEFF	Ring buffer for SIO A
FF00-FFFF	Ring buffer for SIO B

D000-FFFF on the low 64K bank is currently unused.

In ROM the upper 16K holds a 1:1 map of the high memory space. This could be
packed lower to get other things into the ROM, or as the kernel wipes the
BSS and buffer spaces then the ROM version of this space could be used to
hold other things easily enough, and would probably allow E000-FFFF to be
used pretty reliably to hold something else in ROM space.
