#include <kernel.h>

/* Add memory */
void pagemap_init(void)
{
	/* Low 0 is kernel map, high 0 unused except at boot */
	/* 0x11 Kernel code */
	pagemap_add(0x33);
	pagemap_add(0xC3);
	pagemap_add(0xF3);
	pagemap_add(0x0F);
	pagemap_add(0xCF);
	pagemap_add(0x3F);
	pagemap_add(0xFF);
}

void map_init(void)
{
}

uint_fast8_t plt_param(char *p)
{
	used(p);
	return 0;
}
