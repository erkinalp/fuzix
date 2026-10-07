#include <kernel.h>
#include <ttydw.h>
#include <tinyide.h>

void device_init(void)
{
#ifdef CONFIG_COCOIDE
	ide_probe();
#endif
#ifdef CONFIG_COCOSDC
	devsdc_probe();
#endif
#ifdef CONFIG_DRIVEWIRE
	dw_init();
#endif
}
