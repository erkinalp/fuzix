#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <devtty.h>
#include <device.h>
#include <vt.h>
#include <tty.h>
#include "config.h"

#define kbd_read ((volatile uint8_t *)0xE812)
#define kbd_strobe ((volatile uint8_t *)0xE810)
#define irq_check ((volatile uint8_t *)0xE840)
#define irq_reset ((volatile uint8_t *)0xE840)

#define NUM_COLS 80

static char tbuf1[TTYSIZ];
PTY_BUFFERS;

uint8_t vtattr_cap = 0;

// static uint8_t *vtmap = 0x8000;

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
	PTY_QUEUES
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS	/* Nothing configurable */
};

/* tty1 is the screen  */

/* Output for the system console (kprintf etc) */
void kputchar(char c)
{
	if (c == '\n')
		tty_putc(1, '\r');
	tty_putc(1, c);
}


unsigned char vt_map_petscii(unsigned char c)
{
	// assume pet charst with case swaping fixed
	if (c > 0x5F) {
		return c-0x60;
	}
	return c;
}


ttyready_t tty_writeready(uint_fast8_t minor)
{
        return TTY_READY_NOW;
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
        vtoutput(&c,1);
}

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
        minor;
}

void tty_sleeping(uint_fast8_t minor)
{
        minor;
}

int tty_carrier(uint_fast8_t minor)
{
        minor;
        return 1;
}

void tty_data_consumed(uint_fast8_t minor)
{
}

static uint8_t kbd_timer;
uint8_t vtattr_cap;
struct vt_repeat keyrepeat;

/* buffer for port scan procedure */
uint8_t keybuf[8];
/* Previous state */
uint8_t keymap[8];

static uint8_t keybyte, keybit;
static uint8_t newkey;
static int keysdown = 0;

#define RIGHT_SHIFT 1
#define LEFT_SHIFT 2
#define CTRL_KEY 3

uint8_t keyboard[10][8] = {

	{'=', '.', 0, KEY_STOP, '<', 0x20, '[', CTRL_KEY},
	{'9', 0, '^', '7',  '0', '7', '4',  '1' },
	{'+', '2', 0, '?', ',', 'n', 'v', 'x'},
	{'3', '1',0, ';', 'm', 'b', 'c', 'z'},
	{'*', '5', 0, ':', 'k', 'h', 'f', 's'},
	{'6', '4', 0, '1', 'j', 'g', 'd', 'a'},
	{'/', '8', 0, 'p', 'b', 'y', 'r', 'w'},
	{'9', '7', '^', 'o', 'u', 't', 'e', 'q'},
	{KEY_DEL, KEY_DOWN  , 0, ')', '\\', '\'', '$', '"'},
	{KEY_RIGHT, KEY_HOME  , KEY_ESC, '(', '&', '#', '!'}
};

/* SYMBOL SHIFT MODE */
uint8_t shiftkeyboard[10][8] = {
	{KEY_RIGHT, KEY_HOME  , KEY_ESC, '(', '&', '#', '!'},
	{KEY_DEL, KEY_DOWN  , 0, ')', '\\', '\'', '$', '"'},
	{'9', '7', '^', 'o', 'u', 't', 'e', 'q'},
	{'/', '8', 0, 'p', 'i', 'y', 'r', 'w'},
	{'6', '4', 0, '1', 'j', 'g', 'd', 'a'},
	{'*', '5', 0, ':', 'k', 'h', 'f', 's'},
	{'3', '1',13, ';', 'm', 'b', 'c', 'z'},
	{'+', '2', 0, '?', ',', 'n', 'v', 'x'},
	{'-', '0', RIGHT_SHIFT, '>',   0, ']', '@',  LEFT_SHIFT },
	{'=', '.', 0, KEY_STOP, '<', 0x20, '[', CTRL_KEY}
};


static uint8_t shiftmask[8] = { 0x02, 0, 0, 0, 0, 0, 0, 0x01 };
static uint8_t cursor[4] = { KEY_LEFT, KEY_DOWN, KEY_UP, KEY_RIGHT };

static void keydecode(void)
{
	uint8_t c;

	uint8_t ss = keymap[0] & 0x02;	/* SYMBOL SHIFT */
	uint8_t cs = keymap[7] & 0x01;	/* CAPS SHIFT */

	// if (ss) {
	// 	c = shiftkeyboard[keybyte][keybit];
	// } else {
	// 	c = keyboard[keybyte][keybit];
	// 	if (cs) {
	// 		if (c >= 'a' && c <= 'z')
	// 			c -= 'a' - 'A';
	// 		else if (c == '0')	/* CS + 0 is backspace) */
	// 			c = 0x08;
	// 		else if (c == ' ')
	// 			c = KEY_STOP;	/* ^C map for BREAK */
	// 		else if (c >= '5' && c <= '8')
	// 			c = cursor[c - '5'];
	// 	}
	// }
			c = keyboard[keybyte][keybit];

	tty_inproc(1, c);
}

void update_keyboard(void)
{
	int n;
	uint8_t r,t;
	IO_PEEK_ENABLE;
    t= *kbd_strobe;
	// encode keyboard row in bits 0-3 pia1 port a, then read status from pia1 port b
	for (n =0; n < 10; n++) {
		r = (t & 0xf0) | n;
		*kbd_strobe = r;
		keybuf[n] = ~*kbd_read;
	}
    IO_PEEK_DISABLE;
}

void tty_poll(void)
{
	uint8_t i;
	return;

	update_keyboard();

	newkey = 0;

	for (i = 0; i < 10; i++) {
		uint8_t n;
		uint8_t key = keybuf[i] ^ keymap[i];
		if (key) {
				tty_inproc(1, key);

			// uint8_t m = 0x10;
			// for (n = 4; n >= 0; n--) {
			// 	if ((key & m) && (keymap[i] & m))
			// 		if (!(shiftmask[i] & m))
			// 			keysdown--;

			// 	if ((key & m) && !(keymap[i] & m)) {
			// 		if (!(shiftmask[i] & m)) {
			// 			keysdown++;
			// 			newkey = 1;
			// 			keybyte = i;
			// 			keybit = n;
			// 		}
			// 	}
			// 	m >>= 1;
			// }
		}
		keymap[i] = keybuf[i];
	}
	// if (keysdown && keysdown < 3) {
	// 	if (newkey) {
	// 		keydecode();
	// 		kbd_timer = keyrepeat.first;
	// 	} else if (! --kbd_timer) {
	// 		keydecode();
	// 		kbd_timer = keyrepeat.continual;
	// 	}
	// }

}




