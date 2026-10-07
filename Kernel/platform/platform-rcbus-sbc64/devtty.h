#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__

void tty_putc(uint_fast8_t minor, uint_fast8_t c);
void tty_irq_sio0(void);
void tty_irq_sio1(void);
void tty_poll_cpld(void);
int rctty_open(uint_fast8_t minor, uint16_t flag);

#endif
