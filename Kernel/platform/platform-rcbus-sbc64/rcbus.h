#ifndef __RCBUS_SIO_DOT_H__
#define __RCBUS_SIO_DOT_H__

/* Needs generalizing and tidying up across the RCBUS systems */

#include "config.h"

#define SIO0_IVT 8

/* Standard RCBUS */
#define SIO0_BASE 0x80
#define SIOA_C 0x80
#define SIOA_D 0x81
#define SIOB_C 0x82
#define SIOB_D 0x83

#define SIO1_BASE 0x84
#define SIOC_C 0x84
#define SIOC_D 0x85
#define SIOD_C 0x86
#define SIOD_D 0x87

/* ACIA is at same address as SIO but we autodetect */

#define ACIA_BASE 0x80
#define ACIA_C 0x80
#define ACIA_D 0x81

#define CTC_CH(n) (0x88 + (n))

extern void sio2_otir(uint8_t port);

extern uint8_t acia_present;
extern uint8_t ctc_present;
extern uint8_t sio_present;
extern uint8_t sio1_present;

extern void cpld_bitbang(uint8_t c);

#endif
