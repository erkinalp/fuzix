#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <tty.h>

extern uint8_t *uart[8];

void devtty_init()
{
	/* Reset each UART by write to STATUS register */
	*uart[3] = 3;
	*uart[5] = 3;
	*uart[7] = 3;
}
