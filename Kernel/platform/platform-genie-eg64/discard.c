#include <kernel.h>
#include <devhd.h>
#include <devtty.h>
#include <tty.h>
#include <kdata.h>
#include "trs80.h"

void device_init(void)
{
#ifdef CONFIG_RTC
  /* Time of day clock */
  inittod();
#endif
  hd_probe();
  trstty_probe();
}

void map_init(void)
{
}

uint_fast8_t plt_param(char *p)
{
    return 0;
}
