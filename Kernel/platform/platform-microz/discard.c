#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <tinydisk.h>
#include <tinyide.h>

/*
 *	Everything in this file ends up in discard which means the moment
 *	we try and execute init it gets blown away. That includes any
 *	variables declared here so beware!
 */

/*
 *	We get passed each kernel command line argument. if we return 1 then
 *	we claim it, if not it gets passed to init. It's perfectly acceptable
 *	to act on a match and return to also pass it to init if you need to.
 */
uint_fast8_t plt_param(unsigned char *p)
{
	return 0;
}

/*
 *	Set up our memory mappings. This is not needed for simple banked memory
 *	only more complex setups such as 16K paging.
 */
void map_init(void)
{
}

/*
 *	Add all our free pages to the system. They are numbered in pairs as
 *	the system has some h/w logic to fake the 512K RAM/ROM enough for ROMWBW
 *	but not us.
 */
void pagemap_init(void)
{
	pagemap_add(0xC1);	/* 1 higher than value to avoid 0 */
	pagemap_add(0x01);
}

/*
 *	Called after interrupts are enabled in order to enumerate and set up
 *	any devices. In our case we set up the SIO and then probe the CF.
 */

void device_init(void)
{
	ide_probe();
}
