#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <zxuno.h>

extern uint8_t fuller, kempston, kmouse, kempston_mbmask;

void pagemap_init(void)
{
	unsigned i = 1024;

	if (probe_zxuno()) {
		configure_zxuno();
		is_zxuno = 1;
		/* These are always present */
		kempston = 1;
		kmouse = 1;
		fuller = 1;
		radastan = 1;
	}
	pagemap_add(0x01);
	pagemap_add(0x81);

}

uint_fast8_t plt_param(char *p)
{
	if (strcmp(p, "kempston") == 0) {
		kempston = 1;
		return 1;
	}
	if (strcmp(p, "kmouse") == 0) {
		kmouse = 1;
		return 1;
	}
	if (strcmp(p, "fuller") == 0) {
		fuller = 1;
		return 1;
	}
	if (strcmp(p, "kmouse3") == 0) {
		kmouse = 1;
		kempston_mbmask = 7;
		return 1;
	}
	if (strcmp(p, "kmturbo") == 0) {
		/* For now rely on the turbo detect - may want to change this */
		kmouse = 1;
		return 1;
	}
	return 0;
}

/* Nothing to do for the map of init */
void map_init(void)
{
}

void plt_copyright(void)
{
}
