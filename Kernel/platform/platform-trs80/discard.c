#include <kernel.h>
#include <printf.h>
#include <devhd.h>
#include <devtty.h>
#include <devmega.h>
#include <tty.h>

#define GFX_X		0x80
#define GFX_Y		0x81
#define GFX_DATA	0x82
#define GFX_CTRL	0x83
#define GFX_XPAN	0x8C
#define GFX_YPAN	0x8D
#define GFX_XOR		0x8E

/* There are two possible card types. The Tandy version is a 640x240 card with
   hardware panning. The Micro Grafyx is very similar but has no panning and
   has a 512 x 192 mode to match the model 3 modes

   The control port differs as follows
   Tandy
   0: set to turn graphics on, clear for alpha
   1: set to turn on wait states (no flicker on update)

   Micrografyx
   0: set to turn on graphics
   1: if graphics set to turn off text (otherwie xored)

   Unique to Tandy are
   0x8C: X pan byte value 0-127
   0x8D: Y pan 0-255
   0x8E: 1 = xor text and graphics, 0 = graphics only (other bits unknown)
*/

static uint_fast8_t probe_gfx(void)
{
	kputs("Probing gfx: ");
	out(GFX_X, 1);
	out(GFX_Y, 1);
	out(GFX_CTRL, 0x40); /* Graphics off, inc X on read/write */
	out(GFX_DATA, 0x55);
	out(GFX_DATA, 0xAA);
	out(GFX_X, 1);
	if (in(GFX_DATA) != 0x55 || in(GFX_DATA) != 0xAA) {
		kputs("none\n");
		return 0;
	}
	/* We have either a TRS80 or a clone card present */
	out(GFX_X, 0x7F);
	out(GFX_Y, 0xFF);
	out(GFX_CTRL, 0xF0);	/* No inc of X or Y */
	out(GFX_DATA, 0xA5);
	if (in(GFX_DATA) != 0xA5) {	/* this may need to be forced for Grafyx clone */
		kputs("uLabs Grafyx (original)\n");
		return 2;
	}
	kputs("Tandy (assumed) or Grafyx clone (unhandled)\n");
	return 1;
}

void device_init(void)
{
	gfxtype = probe_gfx();
	vtbuf_init();
#ifdef CONFIG_RTC
	/* Time of day clock */
	inittod();
#endif
	/* Probe first as it's our preferred swap */
	mega_probe();
	hd_probe();
	tty_setup(3, 0);
}

void map_init(void)
{
}

uint8_t nbanks = 2;		/* Default 2 banks, unless we probe and find a
				   banked memory card */
extern uint8_t banktype;

/* The Hypermem select is not quite the same as 0 is the upper 64K
   original */
static void hyper_pagemap_init(void)
{
	uint8_t n;
	for (n = 0; n < nbanks; n++) {
		pagemap_add(n | 0x20);	/* Avoid getting a 0 value */
		pagemap_add(n | 0x80);
	}
}

void pagemap_init(void)
{
	uint8_t i = nbanks - 1;
	if (banktype == 2) {
		hyper_pagemap_init();
		return;
	}
	while (i) {
		pagemap_add(i);	/* Mode 3, U64K low 32K mapped as low 32K */
		pagemap_add(i | 0x80);	/* Mode 3, U64K high 32K mapped as low 32K */
		i--;
	}
}
