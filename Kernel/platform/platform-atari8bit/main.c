#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <tinydisk.h>
#include <tinyide.h>
#include <devtty.h>

uint8_t kernel_flag = 1;
uint16_t swap_dev = 0xFFFF;

void plt_idle(void)
{
    irqflags_t flags = di();
    tty_poll();
    irqrestore(flags);
}

void do_beep(void)
{
}

void map_init(void)
{
}

uint_fast8_t plt_param(char *p)
{
    return 0;
}

static volatile uint8_t *via = (volatile uint8_t *)0xFE60;

void device_init(void)
{
	bufsetup();
#ifdef CONFIG_TD_IDE
	ide_probe();
#endif
}

void plt_interrupt(void)
{
	uint8_t dummy;

	tty_poll();
#if 0
	if (via[13] & 0x40) {
		dummy = via[4]; /* Reset interrupt */
		timer_interrupt();
	}
#endif
}

/* TODO: put these into the asm bits */
unsigned strlen(const char *p)
{
	unsigned n = 0;
	while(*p++)
		n++;
	return n;
}

void *memcpy(void *to, const void *from, unsigned len)
{
	const uint8_t *f = from;
	uint8_t *t = to;
	while(len--)
		*t++ = *f++;
	return to;
}

void *memset(void *to, int v, unsigned len)
{
	uint8_t *t = to;
	while(len--)
		*t++ = v;
	return to;
}

