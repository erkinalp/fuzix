#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <rtc.h>

/* Location depends on board generation */
uint8_t rtc_base;

/* Full RTC support (for read - no write yet) */
int plt_rtc_read(void)
{
        irqflags_t irq;
	uint16_t len = sizeof(struct cmos_rtc);
	struct cmos_rtc cmos;
	uint8_t *p = cmos.data.bytes;

	if (udata.u_count < len)
		len = udata.u_count;

        irq = di();
        out(rtc_base + 0x0D, in(rtc_base + 0x0D) | 1);	/* Hold on */
        while(in(rtc_base + 0x0D) & 0x02);	/* spin until not busy */

        /* Now safe to read the clock */
        /* FIXME: we assume 24hr mode */
        p[6] = in(rtc_base) | (in(rtc_base + 1) << 4);
        p[5] = in(rtc_base + 2) | (in(rtc_base + 3) << 4);
        p[4] = in(rtc_base + 4) | ((in(rtc_base + 5) << 4) & 0x30);
        p[3] = in(rtc_base + 6) | (in(rtc_base + 7) << 4);
        p[2] = in(rtc_base + 8) | (in(rtc_base + 9) << 4);
        p[1] = in(rtc_base + 0x0A) | (in(rtc_base + 0x0B) << 4);
        /* Assume 2000 based for now FIXME */
        p[0] = 0x20;

        out(rtc_base + 0x0D, in(rtc_base + 0x0D) & ~1);		/* Hold off */

        irqrestore(irq);
	cmos.type = CMOS_RTC_BCD;

	if (uput(&cmos, udata.u_base, len) == -1)
		return -1;
	return len;
}

int plt_rtc_write(void)
{
	udata.u_error = EOPNOTSUPP;
	return -1;
}

uint_fast8_t plt_rtc_secs(void)
{
        irqflags_t irq;
        uint8_t s;
        irq = di();
        out(rtc_base + 0x0D, in(rtc_base + 0x0D) | 1);	/* Hold on */
        while(in(rtc_base + 0x0D) & 0x02);	/* spin until not busy */
        s = in(rtc_base) + 10 * in(rtc_base + 1);
        out(rtc_base + 0x0D, in(rtc_base + 0x0D) & ~1);	/* Hold off */
        irqrestore(irq);
        return s;
}
