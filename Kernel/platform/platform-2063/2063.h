#ifndef __2063_DOT_H__
#define __2063_DOT_H__

#include "config.h"

#define SIO0_IVT 8

/* Standard RC2014 */
#define SIO0_BASE 0x30
#define SIOA_D	0x30
#define SIOB_D	0x31
#define SIOA_C  0x32
#define SIOB_C	0x33

#define CTC_CH(n)	(0x40 + (n))

extern void sio2_otir(uint8_t port);

extern uint8_t sd_busy;
extern uint8_t sd_count;
extern uint8_t gpio;

#endif
