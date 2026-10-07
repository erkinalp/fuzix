#include <kernel.h>
#include <blkdev.h>
#include <tinysd.h>
#include <z80softspi.h>

/*
 *	SD card bit bang. For now just a single card to get us going. We
 *	should fix the cs asm to allow for multiple cards
 *
 *	Bits
 *	0: MOSI
 *	3: \CS card
 *	4: CLK
 *	7: MISO
 *
 *	We don't use 5-7. We could put an interrupt on these, more CS lines
 *	or another else unrelated.
 *
 *	The 3vZ80 doesn't have a real SPI port but set it up anyway as
 *	if it did that way it'll work with a PIO card on other machines
 */

/* PIO port B */
#define PIOB_D	0x69
#define PIOB_C	0x6B

void pio_setup(void)
{
    spi_piostate = 0x00;
    spi_port = PIOB_D;
    spi_data = 0x01;
    spi_clock = 0x10;

    out(PIOB_C, 0xCF);		/* Mode 3 */
    out(PIOB_C, 0xE6);		/* MISO input, unused as input (so high Z) */
    /* No vector loading for now - might need if we want to support an SPI
       device with interrupts (eg ethernet) */
    out(PIOB_C, 0x07);		/* No interrupt, no mask */
}

void sd_spi_raise_cs(void)
{
    out(PIOB_D, spi_piostate |= 0x08);
}

void sd_spi_lower_cs(void)
{
    spi_piostate &= ~0x08;
    out(PIOB_D, spi_piostate);
}

void sd_spi_fast(void)
{
}

void sd_spi_slow(void)
{
}
