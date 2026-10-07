#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <tty.h>
#include <devtty.h>
#include <agon.h>

static uint8_t tbuf1[TTYSIZ];

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2}
};

/* The VDP link stays at the MOS speed */
tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS
};

static uint8_t vdp_xoff;

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
	used(minor);
	used(flags);
}

int tty_carrier(uint_fast8_t minor)
{
	used(minor);
	return 1;
}

void tty_sleeping(uint_fast8_t minor)
{
	used(minor);
}

void tty_data_consumed(uint_fast8_t minor)
{
	used(minor);
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
	used(minor);
	/* The VDP uses both CTS and XON/XOFF */
	if (vdp_xoff || !(in(UART0_MSR) & 0x10))
		return TTY_READY_SOON;
	if (in(UART0_LSR) & 0x20)
		return TTY_READY_NOW;
	return TTY_READY_SOON;
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	used(minor);
	out(UART0_THR, c);
}

/* kernel writes to system console -- never sleep! */
void kputchar(uint_fast8_t c)
{
	uint16_t n;
	if (c == '\n')
		kputchar('\r');
	/* Time out as nothing clears an XOFF with interrupts off */
	n = 0;
	while (tty_writeready(1) != TTY_READY_NOW && --n);
	tty_putc(1, c);
}

void tty_poll(void)
{
	uint_fast8_t c;

	while (in(UART0_LSR) & 0x01) {
		c = in(UART0_RBR);
		if (c == CTRL('Q'))
			vdp_xoff = 0;
		else if (c == CTRL('S'))
			vdp_xoff = 1;
		else if (c) {
			if (c == 0x7F)
				c = CTRL('H');
			tty_inproc(1, c);
		}
	}
}
