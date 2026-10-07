/*
 *	Olivetti M20 TTY driver
 *
 *	TTY 1: CRT display (BIOS PROM put_char) + keyboard (i8251A at 0xA1)
 *
 *	Keyboard runs at 1200 baud via PIT counter 1 (configured by BIOS PROM).
 *	CRT output via BIOS PROM put_char at 0x84000080.
 *	Serial port at 0xC1 is used only for kprintf debug output.
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <tty.h>
#include <devtty.h>

/* i8251A keyboard port */
#define KBD_DATA	0x00A1
#define KBD_CTRL	0x00A3

/* i8251A status bits */
#define USART_RXRDY	0x02

static uint8_t tbuf1[TTYSIZ];

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {
	{ NULL, NULL, NULL, 0, 0, 0 },					/* ttyinq[0] unused */
	{ tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2 },		/* TTY 1: CRT/kbd */
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS,
};

/*
 *	Olivetti M20 keyboard scan code to ASCII translation table.
 *	256 entries: base[0..47], shift[48..95], ctrl[96..143], cmd[144..191],
 *	             other[192..255] (space, CR, S1, S2, keypad).
 *
 *	From CP/M-8000 BIOS by S. Savitzky (Zilog), 1982.
 */
static const uint8_t kbtran[256] = {
/* Raw key codes for main keypad:
   RE    \    A    B    C    D    E    F    G    H    I    J    K    L    M    N
    O    P    Q    R    S    T    U    V    W    X    Y    Z    0    1    2    3
    4    5    6    7    8    9    -    ^    @    [    ;    :    ]    ,    .    /
*/

/* main keyboard UNSHIFTED (0x00-0x2F) */
0xDD,'\\', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1', '2', '3',
 '4', '5', '6', '7', '8', '9', '-', '^', '@', '[', ';', ':', ']', ',', '.', '/',

/* main keyboard SHIFTED (0x30-0x5F) */
0xDE, '|', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '_', '!', '"', '#',
 '$', '%', '&','\'', '(', ')', '=', '~', '`', '{', '+', '*', '}', '<', '>', '?',

/* main keyboard CONTROL (0x60-0x8F) */
0xA0,0x7F,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,
0x0F,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0xE0,0xE1,0xE2,0xE3,
0xE4,0xE5,0xD6,0xE7,0xE8,0xE9,0xEA,0xEB,0x00,0x1B,0x1E,0x1F,0x1D,0xFE,0xFF,0xA4,

/* main keyboard COMMAND (0x90-0xBF) */
0xDF,0xF8,0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87,0x88,0x89,0x8A,0x8B,0x8C,0x8D,
0x8E,0x8F,0x90,0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0xEC,0xED,0xEE,0xEF,
0xF0,0xF1,0xF2,0xF3,0xF4,0xF5,0xF6,0xF7,0x13,0x1C,0xFC,0xFD,0x9F,0xF9,0xFA,0xA5,

/* other keys UNSHIFTED: SP CR S1 S2 / keypad: . 0 00 1 / 2 3 4 5 / 6 7 8 9 / + - * / */
 ' ','\r',0x7F,0x08,
 '.', '0',0xA6, '1',
 '2', '3', '4', '5',
 '6', '7', '8', '9',
 '+', '-', '*', '/',

/* other keys SHIFTED */
 ' ','\r',0xA8,0xA9,
 '.', '0',0xA6,0x1C,
0x9A,0x1D,0x9B,0x9C,
0x9D,0x1E,0x9E,0x1F,
0x2B,0x2D,0x2A,0x2F,

/* other keys CONTROL */
 ' ','\r',0xA8,0xA9,
0xB0,0xB1,0xB2,0xB3,
0xB4,0xB5,0xB6,0x1B,
0xB8,0xB9,0xBA,0xBB,
0xBC,0xBD,0xBE,0xBF,

/* special */
'\r','\r','\r','\r'
};

/* Output a character via BIOS CRT */
void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	crt_put(c);
}

void tty_sleeping(uint_fast8_t minor)
{
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
	/* BIOS busy-waits internally */
	return TTY_READY_NOW;
}

void tty_data_consumed(uint_fast8_t minor)
{
}

int tty_carrier(uint_fast8_t minor)
{
	return 1;
}

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
	struct tty *t = &ttydata[minor];
	if (flags == 0) {
		t->termios.c_iflag = ICRNL | BRKINT;
		t->termios.c_oflag = ONLCR | OPOST;
		t->termios.c_cflag = CS8 | CREAD | CLOCAL | B1200;
		t->termios.c_lflag = ISIG | ICANON | ECHO | ECHOE | ECHOK;
	}
}

/*
 *	Poll for incoming keyboard data.
 *	Called from the timer interrupt.
 */
void tty_interrupt(void)
{
	uint8_t st;

	st = in(KBD_CTRL);
	if (st & USART_RXRDY) {
		uint8_t scan = in(KBD_DATA);
		uint8_t ch = kbtran[scan];
		if (ch)
			tty_inproc(1, ch);
	}
	/* Clear any overrun/framing/parity errors */
	if (st & 0x38)
		out(KBD_CTRL, 0x37);
}
