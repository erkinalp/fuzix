
extern unsigned megamem_probe(void);
extern void megamem_io(void);

extern uint16_t	mega_io;
extern void *mega_src;
extern void *mega_dest;
extern uint8_t mega_page;

extern int mega_open(uint_fast8_t minor, uint16_t flag);
extern int mega_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int mega_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern void mega_probe(void);


