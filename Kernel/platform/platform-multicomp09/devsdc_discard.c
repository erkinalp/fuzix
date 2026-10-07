#include <kernel.h>
#include <kdata.h>
#include <blkdev.h>
#include <mbr.h>
#include <devsdc.h>
#include <printf.h>

/* Returns true if SD hardware seems to exist */
bool devsd_exist()
{
	/* Only way to boot is through SD so it must
	   exist!
	*/
	return 1;
}

/* Call this to initialize SD/blkdev interface */
void devsd_init()
{
	blkdev_t *blk;

	kputs("SD: ");
	if( devsd_exist() ){
		/* there is only 1 drive. Register it. */
		blk=blkdev_alloc();
		blk->driver_data = 0 ;
		blk->transfer = devsd_transfer_sector;
		blk->flush = devsd_flush;
		blk->drive_lba_count=-1;
		blk->drive_lba_count=32764; /* [NAC HACK 2016Apr26]  hack!! */
		blkdev_scan(blk, 0);

		kputs("ok.\n");
	}
	else kprintf("Not Found.\n");
}
