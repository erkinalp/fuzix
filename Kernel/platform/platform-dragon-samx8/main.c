#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>

uint8_t system_id;
struct blkbuf *bufpool_end = bufpool + NBUFS;
uint16_t swap_dev = 0xFFFF;
uint8_t rtc_shadow;

void plt_idle(void)
{
}

void do_beep(void)
{
}

/*
 *	Once we are about to load init we can throw the boot code away
 *	and convert it into disk cache.
 */
void plt_discard(void)
{
#if CONFIG_BANKS < 4
  uint16_t discard_size = 0xC000 - (uint16_t)bufpool_end;
#else
  uint16_t discard_size = 0xF000 - (uint16_t)bufpool_end;
#endif
  bufptr bp = bufpool_end;

  discard_size /= sizeof(struct blkbuf);

  kprintf("%d buffers reclaimed from discard\n", discard_size);

  bufpool_end += discard_size;	/* Reclaim the discard space */

  memset(bp, 0, discard_size * sizeof(struct blkbuf));

  for (bp = bufpool + NBUFS; bp < bufpool_end; ++bp) {
    bp->bf_dev = NO_DEVICE;
    bp->bf_busy = BF_FREE;
  }

#if CONFIG_BANKS < 4
  pagemap_add(3);
#endif
}
