#ifndef __RC2014_SIO_DOT_H__
#define __RC2014_SIO_DOT_H__

#include "config.h"

/* We have a weird mismatch setup with easy-z80 */
#define SIO0_BASE 0x80
#define SIOA_D	0x80
#define SIOA_C	0x81
#define SIOB_D	0x82
#define SIOB_C	0x83

#define CTC_CH(n)	(0x88 + (n))

extern void sio2_otir(uint8_t port);

extern uint8_t ds1302_present;

#endif
