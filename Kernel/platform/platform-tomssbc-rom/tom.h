#ifndef __TOM_DOT_H__
#define __TOM_DOT_H__

/* Needs generalizing and tidying up across the RC2014 systems */

#include "config.h"

/* SIO 2 ports */

#define SIO0_BASE 0x00
#define SIOA_D	0x00
#define SIOB_D	0x01
#define SIOA_C	0x02
#define SIOB_C	0x03

extern void sio2_otir(uint8_t port);

#endif
