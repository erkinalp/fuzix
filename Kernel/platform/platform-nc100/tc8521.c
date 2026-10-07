/*
 *	This is intended for the NC100. It assumes 24 hour clock mode, no
 *	timer or alarm running. It also for now assumes a 1990 base as the
 *	NC100 does.
 *
 *	This code breaks in 2089.
 */

#include <kernel.h>
#include <kdata.h>
#include <stdbool.h>
#include <printf.h>
#include <rtc.h>

#define CLOCK_PORT	0xD0

extern uint8_t rtc_buf[7];
extern void read_clock(void);

/* Full RTC support (for read - no write yet) */
int plt_rtc_read(void)
{
	uint16_t len = sizeof(struct cmos_rtc);
	uint16_t y;
	struct cmos_rtc cmos;
	uint8_t *p = cmos.data.bytes;

	if (udata.u_count < len)
		len = udata.u_count;

        /* Places 7 BCD pairs into rtc_buf */
	read_clock();

	y = *rtc_buf;
	/* 1990 based year , if its 0x10 or more we are in 2000-2089 and
	   need to adjust the clock up by 2000 and back by 10. If not well
	   then its 1990-1999 so just needs 0x1990 adding to the 0-9 we have */
	if (y >= 0x10)
	    y += 0x19F0;
        else
            y += 0x1990;
	*p++ = y;
	*p++ = y >> 8;
	*p++ = rtc_buf[1];	/* month */
	*p++ = rtc_buf[2];	/* day */
	*p++ = rtc_buf[3];	/* Hour */
	*p++ = rtc_buf[4];	/* Minute */
	*p = rtc_buf[5];	/* Second */
	cmos.type = CMOS_RTC_BCD;
	if (uput(&cmos, udata.u_base, len) == -1)
		return -1;
	return len;
}

int plt_rtc_write(void)
{
	udata.u_error = -EOPNOTSUPP;
	return -1;
}
