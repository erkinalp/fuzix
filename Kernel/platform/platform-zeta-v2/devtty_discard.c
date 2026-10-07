#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <devtty.h>
#include <zeta-v2.h>

extern unsigned char uart0_type;

unsigned char uart0_detect(void);

/* uart0_init - detect UART type, print it, enable FIFO if present
 */
void uart0_init(void)
{
	const char *uart_name;
	uart0_type = uart0_detect();
	switch (uart0_type & UART_NAME) {
	case UART_8250:
		uart_name = "8250";
		break;
	case UART_16450:
		uart_name = "8250A or 16450";
		break;
	case UART_16550:
		uart_name = "16550";
		break;
	case UART_16550A:
		uart_name = "16550A";
		break;
	default:
		uart_name = "Unknown";
	}
	kprintf("UART0 type: %s", uart_name);
	if (uart0_type & UART_CAP_FIFO) {
		kprintf(" (with FIFO");
		if (uart0_type & UART_CAP_AFE)
			kprintf(" and auto-flow control");
		/* the last dot is lost when FIFO is cleaned */
		kprintf("). Enabling FIFO...");
		/* enable FIFOs
                   set interrupt theshold to 8 bytes
                   */
		out(UART0_FCR, 0x83);
	}
	kprintf(".\n");
}

/* uart0_init - detect UART type and capabilities
 */
unsigned char uart0_detect(void)
{
	unsigned char type, scratch;

	type = UART_8250;		/* default */

	/* 8250 doesn't have scratch register, 8250A and later UARTs do.
           */
	out(UART0_SCR, 0x5A);
	if (in(UART0_SCR) != 0x5A)
		goto out;		/* no scratch register - 8250 */

	out(UART0_SCR, 0xA5);
	if (in(UART0_SCR) != 0xA5)
		goto out;		/* no scratch register - 8250 */

	/* Test for FIFO. Enable FIFO, and test bits 6 & 7 of IIR.
	   UARTs with functioning FIFO will have bits 6 and 7 set to 1
	   when FIFO is enabled. Original 16550 with broken FIFO will have
	   only bit 7 set.
           */

	out(UART0_FCR, 0x01);		/* try to enable FIFO */
	scratch = in(UART0_IIR);	/* read IIR */
	out(UART0_FCR, 0x00);		/* disable FIFO */
	scratch &= 0xC0;		/* get FIFO status bits */

	if (!scratch) {
		type = UART_16450;
		goto out;		/* bits 6 and 7 are not set - 16450 */
	}

	if (scratch == 0x80) {
		type = UART_16550;	/* only bit 7 is set - bad 16550 */
		goto out;
	}

	/* Must be 16550A or later. Normally comes with FIFO */
	type = UART_16550A | UART_CAP_FIFO;

	/* TODO: Test for UARTs with EFR */

	/* Test for auto-flow control. This feature is present in some
	   16550 versions (TI TL16C550C, NXP SC16C550B) */
	out(UART0_IER, 0x00);	/* disable interrupts */
	out(UART0_MCR, 0x30);	/* enable auto-flow and loopback */
	out(UART0_IER, 0x08);	/* enable modem status interrupt */
	scratch = in(UART0_MSR);/* read MSR to reset IIR */
	out(UART0_MCR, 0x32);	/* set RTS = 1 */
	scratch = in(UART0_IIR);/* read IIR */
	out(UART0_MCR, 0x00);	/* reset MCR bits */
	scratch &= 0x0F;	/* get the interrupt type bits */

	if (scratch == 0x01)
		/* No interrupt detected, RTS change has been eaten by
		   auto-flow control */
		type |= UART_CAP_AFE;
	scratch = in(UART0_MSR);/* reset IIR again */
out:
	out(UART0_IER, 0x01);	/* enable receive interrupt */
	return type;
}
