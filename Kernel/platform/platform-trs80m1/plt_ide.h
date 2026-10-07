#define data	0x40
#define error	0x41
#define count	0x42
#define sec	0x43
#define cyll	0x44
#define cylh	0x45
#define devh	0x46
#define cmd	0x47
#define status	0x47

#define IDE_REG_DATA	0x40

/* Due to our strange banking needs */
#define IDE_NONSTANDARD_XFER

#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
