#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <blkdev.h>

extern uint8_t fuller, kempston, kmouse, kempston_mbmask;

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

void map_init(void)
{
	/* Banks of 32K free minus one banks worth that is the upper RAM */
	uint8_t i = procmem >> 5;
	kprintf("%d banks available.\n", i);
	while(i--)	/* 3 - 0 are the kernel */
		swapmap_init(i + 4);
}

void plt_copyright(void)
{
}
