#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <device.h>
#include <devlpr.h>

#define LPSTAT	0xA0
#define LPDATA	0x40

int lpr_open(uint_fast8_t minor, uint16_t flag)
{
	minor;
	flag;			// shut up compiler
	return 0;
}

int lpr_close(uint_fast8_t minor)
{
	minor;			// shut up compiler
	return 0;
}

int lpr_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	int c = udata.u_count;
	char *p = udata.u_base;

	minor;
	rawflag;
	flag;			// shut up compiler

	while (c-- > 0) {
		while (in(LPSTAT) & 2) {
			if (need_reschedule()) {
				if (psleep_flags(NULL, flag)) {
					if (udata.u_count)
						udata.u_error = 0;
					return udata.u_count;
				}
			}
		}
		/* Data */
		out(LPDATA, ugetc(p++));
		/* Strobe (1uS) */
		mod_control(0, 0x40);
		mod_control(0x40, 0);
	}
	return udata.u_count;
}
