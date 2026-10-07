#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include "devmega.h"

static uint16_t mega_blocks;
uint16_t mega_io;
void *mega_src;
void *mega_dest;
uint8_t mega_page;

int mega_transfer(uint_fast8_t minor, bool is_read, uint_fast8_t rawflag)
{
	unsigned ct = 0;
	uint16_t nblock;
	uint8_t *dptr;
	uint16_t block;
	uint16_t limit = mega_blocks;

	mega_page = 0;
	if (rawflag == 1) {
		if (d_blkoff(BLKSHIFT))
			return -1;
		mega_page = udata.u_page;
	} else if (rawflag == 2)
		mega_page = swappage;

	/* We will swap over the udata so keep copies */
	dptr = udata.u_dptr;
	nblock = udata.u_nblock;
	block = udata.u_block;

	/* Reserve 512K for minor 0 (swap) */
	if (minor == 1)
		block += 1024;
	else
		limit = 1024;

	while (ct < nblock) {
		/* End of RAMdisc ? */
		if (block >= mega_blocks)
			break;
		mega_io = 0x60 + (block >> 11);	/* 2048 blocks per bank */
		/* At 0xC000 we want one of the 64K pages in this bank holding the
		   16K containing our bits */
		mega_io |= (0x80 + ((block >> 5) & 0x3F)) << 8;	/* 64 x 16K blocks */
		if (is_read) {
			mega_dest = dptr;
			/* Find the sector address */
			mega_src = 0x8000 + ((block & 0x1F) << 9);
		} else {
			mega_src = dptr;
			mega_dest = 0x8000 + ((block & 0x1F) << 9);
		}
		megamem_io();
		dptr += 512;
		ct++;
		block++;
	}
	return ct << 9;
}

int mega_open(uint_fast8_t minor, uint16_t flag)
{
	if (mega_blocks == 0 || minor > 1) {
		udata.u_error = ENODEV;
		return -1;
	}
	return 0;
}

int mega_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return mega_transfer(minor, true, rawflag);
}

int mega_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return mega_transfer(minor, false, rawflag);
}

void mega_probe(void)
{
	uint_fast8_t i;
	mega_blocks = megamem_probe();
	if (mega_blocks) {
		kprintf("megamem: %uKb (512K for swap)\n", mega_blocks / 2);
		swap_dev = 0x800;
		/* We reserve 512K so 16 x 32K */
		/* Currently we can only use 16 */
		for (i = 0; i < 16; i++)
			swapmap_init(i);
	}
}
