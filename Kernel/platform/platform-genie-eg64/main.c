#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <rtc.h>
#include <devtty.h>
#include <trs80.h>

uint16_t ramtop = PROGTOP;
uint8_t trs80_model;
uint8_t vtattr_cap;

/*
 *	Called when there is no work to do. On the models without serial
 *	interrupts we poll here so that the normal case of idling while
 *	waiting for input feels ok.
 */
void plt_idle(void)
{
  irqflags_t irq;
  irq = di();
  tty_poll();
  irqrestore(irq);
}

void do_beep(void)
{
}

void plt_interrupt(void)
{
  uint8_t irq = ioread(0x37E0);

  tty_interrupt();
  kbd_interrupt();

  if (irq & 0x40)
    ioread(0x37EC);
  if (irq & 0x80) {
    timer_interrupt();
    ioread(0x37E0);	/* Ack the timer */
  }
}

struct blkbuf *bufpool_end = &bufpool[NBUFS];

void plt_discard(void)
{
	bufptr bp;
	uint16_t space = (uint8_t *)PROGBASE - (uint8_t *)bufpool_end;
        memset(bufpool_end, 0, space);
	space /= sizeof(blkbuf);
	bufpool_end += space;
	kprintf("Reclaiming memory.. total buffers %d\n",
	  bufpool_end - bufpool);
	for( bp = bufpool + NBUFS; bp < bufpool_end; ++bp ){
		bp->bf_dev = NO_DEVICE;
		bp->bf_busy = BF_FREE;
	}
}

#ifdef CONFIG_RTC

#define RTC_SECL	0xB0
#define RTC_SECH	0xB1
#define RTC_MINL	0xB2
#define RTC_MINH	0xB3
#define RTC_HOURL	0xB4
#define RTC_HOURH	0xB5
#define RTC_DOW		0xB6
#define RTC_DAYL	0xB7
#define RTC_DAYH	0xB8
#define RTC_MONL	0xB9
#define RTC_MONH	0xBA
#define RTC_YEARL	0xBB
#define RTC_YEARH	0xBC

/* FIXME: the RTC is optional so we should test for it first */
uint_fast8_t plt_rtc_secs(void)
{
    uint8_t sl, rv;
    /* BCD encoded */
    do {
        sl = in(RTC_SECL);
        /* RTC may be absent */
        if (sl == 255)
          return 255;
        rv = sl + in(RTC_SECH) * 10;
    } while (sl != in(RTC_SECL));
    return rv;
}

/* If the compiler segfaults here you need at least SDCC #10471 */

int plt_rtc_read(void)
{
    uint16_t len = sizeof(struct cmos_rtc);
    struct cmos_rtc cmos;
    uint8_t *p;
    uint8_t r, y;

    if (udata.u_count < len)
        len = udata.u_count;

    if (in(RTC_SECL) == 255) {
      udata.u_error = EOPNOTSUPP;
      return -1;
    }

    /* We do a full set of reads and if the seconds change retry - we
       need to retry the lost as we might read as the second changes for
       new year */
    do {
      p = cmos.data.bytes;
      r = in(RTC_SECL);;
      y  = (in(RTC_YEARH) << 4) | in(RTC_YEARL);
      if (y >= 0x70)
          *p++ = 0x19;
      else
          *p++ = 0x20;
      *p++ = y;
      *p++ = ((in(RTC_MONH) & 1)<< 4) | in(RTC_MONL);
      *p++ = ((in(RTC_DAYH) & 3) << 4) | in(RTC_DAYL);
      *p++ = ((in(RTC_HOURH) & 3) << 4) | in(RTC_HOURL);
      *p++ = ((in(RTC_MINH) & 7) << 4) | in(RTC_MINL);
      *p++ = ((in(RTC_SECH) & 7) << 4) | in(RTC_SECL);
    } while ((r ^ in(RTC_SECL)) & 0x0F);

    cmos.type = CMOS_RTC_BCD;
    if (uput(&cmos, udata.u_base, len) == -1)
        return -1;
    return len;
}

/* Yes I'm a slacker .. this wants adding but it's ugly
   because the seconds is always just set to 0 on any change. We
   also need to deal with leap years here */
int plt_rtc_write(void)
{
	udata.u_error = EOPNOTSUPP;
	return -1;
}

#endif
