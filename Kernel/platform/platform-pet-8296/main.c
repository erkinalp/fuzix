#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <blkdev.h>
#include <devide.h>
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

void *memmove(void *dest, const void *src, size_t n) {
	memcpy(dest, src, n);
}


/*
 * Map handling: allocate 1 banks per process
 */

void pagemap_init(void)
{
	pagemap_add(1);
	pagemap_add(2);
 //   int i;
    /* Add the user banks, taking care to land 36 as the last one as we
       use that for init  (32-35 are the kernel) */
//    for (i = 6; i >= 0; i--)
//        pagemap_add(36 + i * 4);
}

void map_init(void)
{
}

uint8_t plt_param(char *p)
{
    return 0;
}

static volatile uint8_t *via = (volatile uint8_t *)0xe840;

void device_init(void)
{
	/* FIXME: the pet kernal sets up an interrupt driven by hsync
	   just keep it..*/
	/* Timer 1 free running */
	IO_PEEK_ENABLE;
	via[11] = 0x40;
	via[4] = 0x10;	/* 25Hz at 1MHz */
	via[5] = 0x9C;
	via[14] = 0x7F;	/* Clear IER */
	via[14] = 0xC0;	/* Enable Timer 1 */
	IO_PEEK_DISABLE;
#ifdef CONFIG_IDE
	devide_init();
#endif
}

void plt_interrupt(void)
{
	// fixme check correct interrupt
	tty_poll();
	timer_interrupt();
}

/* For now this and the supporting logic don't handle swap */

extern uint8_t hd_map;
extern void hd_read_data(uint8_t *p);
extern void hd_write_data(uint8_t *p);

void devide_read_data(void)
{
	if (blk_op.is_user)
		hd_map = 1;
	else
		hd_map = 0;
	hd_read_data(blk_op.addr);	
}

void devide_write_data(void)
{
	if (blk_op.is_user)
		hd_map = 1;
	else
		hd_map = 0;
	hd_write_data(blk_op.addr);	
}

