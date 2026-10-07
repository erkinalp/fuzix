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

/* a "simple" internal function pointer to which transfer
   routine to use.
*/
typedef void (*sdc_transfer_function_t)(unsigned char *addr);

static bool while_busy(void) {
	uint8_t t;
	do {
		t = sdc_reg_stat;
		if (t & SDC_FAIL)
			return 0;
	} while (t & SDC_BUSY);
	return 1;
}

/* Called after writing a command to wait until the SDC is ready.  You're
 * supposed to wait at least 16us after writing the command, and the function
 * call over head + intialisation of 't' here satisfies that. */

static bool until_ready(void) {
	uint8_t t = 0;
	do {
		t = sdc_reg_stat;
		if (t & SDC_FAIL)
			return 0;
	} while (!(t & SDC_READY));
	return 1;
}

/* blkdev method: transfer sectors */
int sdc_xfer(uint_fast8_t dev, bool is_read, uint32_t lba, uint8_t * dptr)
{
	uint8_t ret = 0;	/* our return value, preset to failure */
	uint8_t *ptr;		/* points to 32 bit lba in blk op */
	int i;			/* iterator */
	uint8_t t;		/* temporarory sdc status holder */
	uint8_t cmd;		/* holds SDC command value */
	sdc_transfer_function_t fptr;	/* holds which xfer routine we want */

	/* turn on uber-secret SDC LBA mode */
	sdc_reg_ctl = SDC_LBA_MODE;

	/* we get 256 bytes per lba in SDC so convert */
	lba *= 2;

	/* setup cmd pointer and command value from blk_op */
	if (is_read) {
		cmd = 0x80;
		fptr = devsdc_read;
	} else {
		cmd = 0xa0;
		fptr = devsdc_write;
	}

	/* or in our drive value */
	cmd |= dev;

	/* wait until not busy */
	if (!while_busy())
		goto fail;

	/* get/send two sectors (512 bytes) of data */
	for (i = 0; i < 2; i++) {
		/* load up registers */
		ptr = ((uint8_t *) (&lba)) + 1;
		sdc_reg_param1 = ptr[0];
		sdc_reg_param2 = ptr[1];
		sdc_reg_param3 = ptr[2];
		sdc_reg_cmd = cmd;
		/* delay after command write, then wait until ready */
		if (!until_ready())
			goto fail;
		/* do our low-level xfer function */
		fptr(dptr);
		/* wait until ready again, testing for failure */
		if (!while_busy())
			goto fail;
		/* increment our blk_op values for next 256 bytes sector */
		lba++;
		dptr += 256;
	}
	/*  Huzzah!  success! */
	ret = 1;
	/* Boo!  failure */
fail:
	sdc_reg_ctl = 0x00;
	return ret;
}
