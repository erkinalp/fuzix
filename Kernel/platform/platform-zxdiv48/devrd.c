/*
 * DivIDE Plus RAM bank ramdisc driver
 *
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <divrd.h>

static int rd_transfer(uint_fast8_t is_read, uint_fast8_t rawflag)
{
    int ct = 0;
    uint16_t nblock = udata.u_nblock;
    blkno_t block = udata.u_block;


    rd_wr = is_read;
    rd_dptr = udata.u_dptr;

    /* It's a disk but only for swapping (and rd_io isn't general purpose) */
    if(rd_dptr < (uint8_t *)0x4000 || rawflag == 1) {
        udata.u_error = EIO;
        return -1;
    }

    /* udata could change under us so keep variables privately */
    while (ct < nblock) {
        rd_page = (block >> 5);		/* 0-3 are kernel */
        rd_addr = (block & 31) << 9;
        rd_io();
        block++;
        rd_dptr += BLKSIZE;
        ct++;
    }
    return ct << BLKSHIFT;
}

int rd_open(uint_fast8_t minor, uint16_t flag)
{
    if(minor != 0) {
        udata.u_error = ENODEV;
        return -1;
    }
    return 0;
}

int rd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    return rd_transfer(true, rawflag);
}

int rd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    return rd_transfer(false, rawflag);
}

