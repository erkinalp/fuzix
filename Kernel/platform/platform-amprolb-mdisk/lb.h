#ifndef __LB_H__
#define __LB_H__

#include "config.h"

#define DART0_BASE	0x80
#define DARTA_D		0x80
#define DARTA_C 	0x84
#define DARTB_D 	0x88
#define DARTB_C 	0x8C

#define CTC_CH(n)	(0x40 + 0x10 * (n))

#define BCR 		0x00
#define BCR_FDC16	0x80
#define BCR_ROMOUT	0x40
#define BCR_SDEN	0x20
#define BCR_SIDE1	0x10
#define BCR_DS		0x0F

#define	LPDATA		0x01
#define LPSTON		0x02
#define LPSTROFF	0x03

#define	FD_WCR		0xC0
#define FD_WTR		0xC1
#define FD_WSR		0xC2
#define FD_WDR		0xC3
#define FD_RCR		0xC4
#define FD_RTR		0xC5
#define	FD_RSR		0xC6
#define FD_RDR		0xC7

#define NCR5380_BASE	0x20

extern void dart_otir(uint8_t port);

#endif
