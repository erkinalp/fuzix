/*
 *	This is intended for the NC200. It assumes 24 hour clock mode and
 *	decimal. The year is 1990 based. This is all fine for the NC200
 *	as that is how the firmware/OS leave it.
 */

#include <kernel.h>
#include <kdata.h>
#include <stdbool.h>
#include <printf.h>
#include <rtc.h>

/* assumes DI from caller */
static uint8_t rtc_reg(uint8_t r)
{
	out(0xD0, r);
	r = in(0xD1);
	return r;
}

uint_fast8_t plt_rtc_secs(void)
{
        static uint8_t last;
        if (rtc_reg(10) & 0x80)
            return last;
        return rtc_reg(0);
}


/* Full RTC support (for read - no write yet) */
int plt_rtc_read(void)
{
	uint16_t len = sizeof(struct cmos_rtc);
	uint16_t y;
	irqflags_t flags;
	struct cmos_rtc cmos;
	uint8_t *p = cmos.data.bytes;

	if (udata.u_count < len)
		len = udata.u_count;

sync:
        while(rtc_reg(10) & 0x80);	/* Wait for UIP to clear */

        flags = di();
        if (rtc_reg(10) & 0x80) {
        	irqrestore(flags);
        	goto sync;
	}

        /* We are now safe for 244uS */
	y = rtc_reg(9) + 1990;
	*p++ = y;
	*p++ = y >> 8;
	*p++ = rtc_reg(8) - 1;
	*p++ = rtc_reg(7);
        *p++ = rtc_reg(4);
        *p++ = rtc_reg(2);
        *p++ = rtc_reg(0);
        irqrestore(flags);

	cmos.type = CMOS_RTC_DEC;
	if (uput(&cmos, udata.u_base, len) == -1)
		return -1;
	return len;
}

int plt_rtc_write(void)
{
	udata.u_error = -EOPNOTSUPP;
	return -1;
}
