#include <kernel.h>
#include <tinysd.h>
#include <printf.h>

#define ZXMMC_CS	0x1F
#define ZXMMC_DATA	0x3F

void sd_spi_raise_cs(void)
{
    out(ZXMMC_CS, 0xF7);		/* Active low NMI off */
}

void sd_spi_tx_byte(uint_fast8_t b)
{
    out(ZXMMC_DATA, b);
}

uint_fast8_t sd_spi_rx_byte(void)
{
    return in(ZXMMC_DATA);
}

void sd_spi_lower_cs(void)
{
    if (tinysd_unit == 0)
      out(ZXMMC_CS, 0xF6);	/* Lower bit 0 (active low) */
    else
      out(ZXMMC_CS, 0xF5);	/* Lower bit 1 (active low) */
}

void sd_spi_fast(void)
{
}

void sd_spi_slow(void)
{
}
