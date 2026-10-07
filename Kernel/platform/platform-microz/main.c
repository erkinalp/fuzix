#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <devtty.h>
#include <microz.h>

struct blkbuf *bufpool_end = bufpool + NBUFS;	/* minimal for boot -- expanded after we're done with _DISCARD */
uint16_t swap_dev = 0xFFFF;
uint16_t ramtop = 0xD000;

void plt_discard(void)
{
#if 0
	while (bufpool_end < (struct blkbuf *) (0xFDFF - sizeof(struct blkbuf))) {
		memset(bufpool_end, 0, sizeof(struct blkbuf));
#if BF_FREE != 0
		bufpool_end->bf_busy = BF_FREE;	/* redundant when BF_FREE == 0 */
#endif
		bufpool_end->bf_dev = NO_DEVICE;
		bufpool_end++;
	}
#endif
}

static uint8_t idlect;

void plt_interrupt(void)
{
	uint8_t n = 255 - in(CTC_CH(3));
	tty_drain_sio();
	out(CTC_CH(3), 0x47);
	out(CTC_CH(3), 255);
	while(n > 0) {
		timer_interrupt();
		n--;
	}
}
