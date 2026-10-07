/*
 *	RAMdisc driver
 */

int rd_open(uint_fast8_t minor, uint16_t flags);
int rd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int rd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);

extern uint8_t rd_wr;
extern uint8_t *rd_dptr;
extern uint8_t rd_page;
extern uint16_t rd_addr;

void rd_io(void);
