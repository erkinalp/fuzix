/*-----------------------------------------------------------------------*/
/* CSI/O SPI driver                                                      */
/* 2014-12-27 Will Sowerbutts                                            */
/* 2014-12-29 Optimised for size/speed                                   */
/*                                                                       */
/* Updated for SC126 to use GPIO interface at port 0x0C			 */
/*-----------------------------------------------------------------------*/

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <stdbool.h>
#include "config.h"
#include <z180.h>
#include <blkdev.h>
#include <tinysd.h>
#include <riz180.h>

#define CSIO_CNTR_TE           (1<<4)   /* transmit enable */
#define CSIO_CNTR_RE           (1<<5)   /* receive enable */
#define CSIO_CNTR_END_FLAG     (1<<7)   /* operation completed flag */

extern  uint8_t reverse_byte(uint8_t byte);

void sd_spi_fast(void)
{
    out(CSIO_CNTR, in(CSIO_CNTR) & 0xf8); /* clear low three bits, gives fastest rate (clk/20) */
}

void sd_spi_slow(void)
{
    unsigned char c;

    c = in(CSIO_CNTR) & 0xf8; /* clear low three bits, gives fastest rate (clk/20) */
    /* set low two bits, clk/160 (can go down to clk/1280, see data sheet) */
    out(CSIO_CNTR, c | 0x03);
}

/* TODO: we need to work out what to borrow for CS */

void sd_spi_lower_cs(void)
{
    /* wait for idle */
    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    out(ASCI_CNTLA0, in(ASCI_CNTLA0) & ~0x10);		/* RTS is borrowed for SPI CS */
}

void sd_spi_raise_cs(void)
{
    /* wait for idle */
    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    /* Set both CS bits back */
    out(ASCI_CNTLA0, in (ASCI_CNTLA0) | 0x10);		/* RTS back up */
}

void sd_spi_tx_byte(uint_fast8_t byte)
{
    unsigned char c;
//    kprintf("[W%d]", byte);

    /* reverse the bits before we busywait */
    byte = reverse_byte(byte);

    /* wait for any current transmit operation to complete */
    do{
        c = in(CSIO_CNTR);
    }while(c & CSIO_CNTR_TE);

    /* write the byte and enable transmitter */
    out(CSIO_TRDR, byte);
    out(CSIO_CNTR, c | CSIO_CNTR_TE);
}

uint_fast8_t sd_spi_rx_byte(void)
{
    unsigned char c;

    /* wait for any current transmit or receive operation to complete */
    do{
        c = in(CSIO_CNTR);
    }while(c & (CSIO_CNTR_TE | CSIO_CNTR_RE));

    /* enable receive operation */
    out(CSIO_CNTR, c | CSIO_CNTR_RE);

    /* wait for receive to complete */
    while(in(CSIO_CNTR) & CSIO_CNTR_RE);

    /* read byte */
    c = reverse_byte(in(CSIO_TRDR));
//    kprintf("[R%x]", c);
    return c;
}

