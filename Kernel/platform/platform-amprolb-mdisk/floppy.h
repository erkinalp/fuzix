/* floppy.s asm interface */
extern uint8_t wd_restore(void);
extern uint8_t wd_seek(uint8_t s);
extern uint8_t wd_setup(uint16_t ts);
extern uint8_t wd_write(uint8_t *data);
extern uint8_t wd_read(uint8_t *data);

/* Latch control */
extern uint8_t set_latch(uint16_t maskdata);

/* Page for disk I/O */
extern uint8_t wd_map;
