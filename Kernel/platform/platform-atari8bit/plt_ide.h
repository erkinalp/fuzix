#define data	((volatile uint8_t *)0xD500)
#define error	((volatile uint8_t *)0xD501)
#define count	((volatile uint8_t *)0xD502)
#define sec	((volatile uint8_t *)0xD503)
#define cyll	((volatile uint8_t *)0xD504)
#define cylh	((volatile uint8_t *)0xD505)
#define devh	((volatile uint8_t *)0xD506)
#define status	((volatile uint8_t *)0xD507)
#define cmd	((volatile uint8_t *)0xD507)

/* It's a 16bit interface but for writes you need to write the pairs backwards
   to read as it's a byte and latch setup */
#define IDE_NONSTANDARD_XFER
