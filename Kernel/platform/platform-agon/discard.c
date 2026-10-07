#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <tinydisk.h>
#include <tinysd.h>
#include <agon.h>

/*
 *	Everything in this file ends up in discard which means the moment
 *	we try and execute init it gets blown away. That includes any
 *	variables declared here so beware!
 */

uint_fast8_t plt_param(unsigned char *p)
{
	used(p);
	return 0;
}

void map_init(void)
{
}

void pagemap_init(void)
{
	uint_fast8_t i;
	for (i = 0x05; i <= 0x0B; i++)
		pagemap_add(i);
}

/* Throw away VDP input for about 100ms */
static void vdp_flush(void)
{
	uint16_t n = 20000;
	while (--n)
		if (in(UART0_LSR) & 0x01)
			in(UART0_RBR);
}

/* Drop any MOS packets and the XON sent once in terminal mode */
void vdp_terminal_init(void)
{
	vdp_flush();
	/* VDU 23,0,255 */
	kputchar(23);
	kputchar(0);
	kputchar(255);
	vdp_flush();
}

void device_init(void)
{
	uint8_t r;

	r = sd_init(0);
	if (r == 0)
		return;
	kputs("sd0: ");
	sd_shift[0] = (r & CT_BLOCK) ? 0 : 9;
	td_register(0, sd_xfer, td_ioctl_none, 1);
	/* hda1 is the MOS FAT partition */
	set_boot_line("hda2");
}
