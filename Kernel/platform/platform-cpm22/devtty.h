#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__
void tty_pollirq(void);
int my_tty_open(uint_fast8_t minor, uint16_t flags);
#endif
