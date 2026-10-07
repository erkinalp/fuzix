#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <device.h>
#include <devtty.h>
#include <tinydisk.h>
#include <tinysd.h>
#include <sd.h>
#include <devinput.h>

void map_init(void)
{
}

void pagemap_init(void)
{
	uint_fast8_t i;
	pagemap_add(0xE1);	/* E8 18 */
	pagemap_add(0x95);	/* 98 58 */
}

void to_sd_probe(void)
{
	kputs("Probing SDDrive\n");
	sd_type = SDIF_SDDRIVE;
	sd_probe();
#if 0
	/* Need to debug these and double check their 6846 interactions etc */
	sdmoto_init();
	kputs("Probing SDMoto\n");
	sd_type = SDIF_SDMOTO;
	do_sd_probe();
	kputs("Probing SDMo\n");
	sd_type = SDIF_SDMO;
	do_sd_probe();
#endif
}
