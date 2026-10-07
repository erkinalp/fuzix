# Fuzix for the 'SmallZ80' from stack180.com

## Supported Hardware

- SmallZ80
- Optional dual serial card/floppy

## Unsupported

Floppy interface

## Installation

make diskimage produces a bootable disk.img file that is a raw image
suitable for writing to disk.

Boot with 'G' return, as with CP/M

## Memory Map

The system has a peculiar "mid 32K" banked arrangement. Fuzix thus
packs the kernel such that the common spaces and data/bss are top and
bottom. If you adjust the size or maps make sure that only code segment
objects exist between 4000 and BFFF in the kernel map.
