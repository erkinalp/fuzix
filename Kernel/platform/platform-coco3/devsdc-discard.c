/*

 CoCoSDC driver
 (c)2015 Brett M. Gordon GPL2

 * Needs work on extended SDC API stuff.
 * init / mounting stuff really needs to set/update blkdev structure for size
 * need to get rawmode=1 and 2 working.

*/

#include <kernel.h>
#include <kdata.h>
#include <tinydisk.h>
#include <devsdc.h>
#include <printf.h>

#include "devsdc.h"

/* Returns true if SDC hardware seems to exist */
bool devsdc_exist(void)
{
	uint8_t t;
	sdc_reg_data = 0x64;
	t = sdc_reg_fctl;
	sdc_reg_data = 0x00;
	if ((sdc_reg_fctl ^ t) == 0x60)
		return 1;
	else
		return 0;
}

/* Call this to initialize SDC/blkdev interface */
void devsdc_probe(void)
{
	if (devsdc_exist()) {
		td_register(0, sdc_xfer, td_ioctl_none, 1);
		td_register(1, sdc_xfer, td_ioctl_none, 1);
	}
}
