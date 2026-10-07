#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include "config.h"
#ifdef CONFIG_FLOPPY
#include <devfd.h>
#endif

extern unsigned char irqvector;
uint16_t swap_dev = 0xFFFF;
struct blkbuf *bufpool_end = bufpool + NBUFS; /* minimal for boot -- expanded after we're done with _DISCARD */

/* Real time clock support for DS1302 driver - port and other pins */
uint16_t rtc_port = 0x70;
uint8_t rtc_shadow;

void plt_discard(void)
{
    while(bufpool_end < (struct blkbuf*)(KERNTOP - sizeof(struct blkbuf))){
        memset(bufpool_end, 0, sizeof(struct blkbuf));
#if BF_FREE != 0
        bufpool_end->bf_busy = BF_FREE; /* redundant when BF_FREE == 0 */
#endif
        bufpool_end->bf_dev = NO_DEVICE;
        bufpool_end++;
    }
}

void plt_interrupt(void)
{
	switch(irqvector) {
		case 1:
#ifdef CONFIG_FLOPPY
			fd_tick();
#endif
			timer_interrupt();
			return;
		case 2:
			tty_pollirq_uart0();
			return;
		default:
			return;
	}
}
