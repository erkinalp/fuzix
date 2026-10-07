/*-----------------------------------------------------------------------*/
/* N8VEM Mark IV Z180 CSI/O SPI SD driver                                */
/* 2014-12-27 Will Sowerbutts                                            */
/* 2014-12-29 Optimised for size/speed                                   */
/*-----------------------------------------------------------------------*/

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <stdbool.h>
#include "config.h"
#include <z180.h>
#include <tinysd.h>

#define CSIO_CNTR_TE           (1<<4)   /* transmit enable */
#define CSIO_CNTR_RE           (1<<5)   /* receive enable */
#define CSIO_CNTR_END_FLAG     (1<<7)   /* operation completed flag */

#define MARK4_SD_CS            (1<<2)   /* chip select */
#define MARK4_SD_WRITE_PROTECT (1<<4)   /* write protect */
#define MARK4_SD_CARD_DETECT   (1<<5)   /* card detect */
#define MARK4_SD_INT_ENABLE    (1<<6)   /* interrupt enable */
#define MARK4_SD_INT_PENDING   (1<<7)   /* interrupt enable */

#define MARK4_SD	(MARK4_IO_BASE + 0x09)

extern uint8_t reverse_byte(uint8_t b);

void sd_spi_slow(void)
{
    /* set low two bits, clk/160 (can go down to clk/1280, see data sheet) */
    out(CSIO_CNTR, (in(CSIO_CNTR) & 0xf8) | 3);
}

void sd_spi_fast(void)
{
    /* clear low three bits, gives fastest rate (clk/20) */
    out(CSIO_CNTR, in(CSIO_CNTR) & 0xf8);
}

void sd_spi_raise_cs(void)
{
    /* wait for idle */
    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    out(MARK4_SD, in(MARK4_SD) & ~MARK4_SD_CS);
}

void sd_spi_lower_cs(void)
{
    /* wait for idle */
    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    out(MARK4_SD, in(MARK4_SD) | MARK4_SD_CS);
}

void sd_spi_tx_byte(uint_fast8_t byte)
{
    unsigned char c;

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
    return reverse_byte(in(CSIO_TRDR));
}

