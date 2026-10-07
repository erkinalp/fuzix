#include <kernel.h>
#include <tinysd.h>
#include "printf.h"

#define DIVMMC_CS	0xE7
#define DIVMMC_DATA	0xEB

void sd_spi_raise_cs(void)
{
    out(DIVMMC_CS, 0xFF);//0x03;		/* Active low */
}

void sd_spi_tx_byte(uint_fast8_t b)
{
    out(DIVMMC_DATA, b);
}

uint_fast8_t sd_spi_rx_byte(void)
{
    return in(DIVMMC_DATA);
}

/*
 *	The ZX Uno works on the bits, Zesarux for some reason
 *	just does "FE is card 0 else card 1", meaning you can't unselect
 *	and it mishandles most values.
 */
void sd_spi_lower_cs(void)
{
    if (tinysd_unit == 0)
      out(DIVMMC_CS, 0xFE);	/* Lower bit 0 (active low) */
    else
      out(DIVMMC_CS, 0xFD);	/* Lower bit 1 (active low) */
}

void sd_spi_fast(void)
{
}

void sd_spi_slow(void)
{
}

#if 0
COMMON_MEMORY

/*
 * FIXME: swap support
 *
 * Could also unroll these a bit for speed
 */

bool sd_spi_rx_sector(uint8_t *data) __naked SD_SPI_CALLTYPE
{
  __asm
#ifdef SD_SPI_BANKED
    pop bc
    pop de
    pop hl
    push hl
    push de
    push bc
#endif
    ld a, (_td_raw)
    push af
#ifdef SWAPDEV
    cp #2
    jr nz, not_swapin
    ld a,(_td_page)
    call map_for_swap
    jr doread
not_swapin:
#endif
    or a
    call nz,map_proc_always
doread:
    ld bc, #0xEB	 ; b = 0, c = port
    ld a,#0x05
    out (0xfe),a
    inir
    ld a,#0x02
    out (0xfe),a
    inir
    ld a,(_vtborder)
    out (0xfe),a
    pop af
    or a
    jp nz,map_kernel
    ret
  __endasm;
}

bool sd_spi_tx_sector(uint8_t *data) __naked SD_SPI_CALLTYPE
{
  __asm
#ifdef SD_SPI_BANKED
    pop bc
    pop de
    pop hl
    push hl
    push de
    push bc
#endif
    ld a, (_td_raw)
    push af
#ifdef SWAPDEV
    cp #2
    jr nz, not_swapout
    ld a, (_td_page)
    call map_for_swap
    jr dowrite
not_swapout:
#endif
    or a
    call nz,map_proc_always
dowrite:
    ld bc, #0xEB
    ld a,#0x05
    out (0xfe),a
    otir
    ld a,#0x02
    out (0xfe),a
    otir
    ld a,(_vtborder)
    out (0xfe),a
    pop af
    or a
    jp nz,map_kernel
    ret
  __endasm;
}
#endif
