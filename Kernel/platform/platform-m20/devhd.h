#ifndef _DEVHD_H
#define _DEVHD_H

int hd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int hd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int hd_open(uint_fast8_t minor, uint16_t flag);

#endif
