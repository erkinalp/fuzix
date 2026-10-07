/*
 *	Thomson Monitor Interface
 */

struct monitor {
    uint8_t lend[0x19];
    uint8_t status;
#define ST_KSCAN	0x01
#define ST_KEYRPT	0x02
#define ST_CURSOR	0x04
#define ST_BEEPOFF	0x08
#define ST_TSPTEXT	0x10
#define ST_SMSCROLL	0x40
#define ST_CAPSLOCK	0x80
    uint8_t tabpt;
    uint8_t rang;		/* Cursor X */
    uint8_t coln;		/* Cursor Y */
    uint8_t toptab;		/* Window top */
    uint8_t topran;		/* Window left */
    uint8_t bottab;		/* Window bottom */
    uint8_t botran;		/* Window right */
    uint16_t scrpt;		/* Screen pointer */
    uint16_t stadr;		/* Window start */
    uint16_t enddr;		/* Window end */
    uint16_t blockz;		/* Zero */
    uint8_t forme;		/* Character colour */
    uint8_t atrang;		/* Attribute */
#define ATR_DWIDTH	0x01
#define ATR_DHEIGHT	0x02
#define ATR_FGSCREEN	0x40
#define ATR_BGSCREEN	0x80
    uint8_t color;		/* Colour for putch */
    uint8_t pagflg;		/* Set to disable scrolling */
    uint8_t scrols;		/* Set to enable smooth scrolling */
    uint8_t cursfl;		/* Cursor end of line marker */
    uint8_t copchr;		/* Holds code of character under cursor */
    uint8_t efmcpt;		/* Cursor blink downcount */
    uint8_t itcmpt;		/* 50Hz interrupt up counter */
    uint16_t plotx;		/* X co-ordinate */
    uint16_t ploty;		/* Y co-ordinate */
    uint8_t chdraw;		/* 0 = pixels 1+ = ascii chars to draw */
    uint8_t key;		/* Last key returned by getch */
    uint8_t cmptkb;		/* Keyboard repeat delay counter */
    uint8_t tempo;		/* Note length multiplier */
    uint8_t duree;		/* Note length */
    uint8_t wave;		/* Wave shape 0-5 */
    uint8_t octave;		/* Octave multiplier 16-1 bass to treble */
    uint8_t k7data;		/* Byte being read from/written to tape */
    uint8_t k7leng;		/* Byte counter of current block */
    uint8_t propc;		/* Printer operation code */
    uint8_t prsta;		/* Printer status */
#define PR_OPEN		0x04
#define PR_READY	0x08
#define PR_CLOSED	0x10
    uint16_t temp;		/* Scratch */
    uint16_t savest;		/* Saved stack pointer */
    uint8_t dkopc;
#define DK_INIT		0x01
#define DK_READ		0x02
#define DK_SD		0x04
#define DK_WRITE	0x08
#define DK_DD		0x10
#define DK_SEEK0	0x20
#define DK_SEEK		0x40
#define DK_VERIFY	0x80
    uint8_t dkdrv;		/* Drive active 0/1 A 2/3 B 4 RAM */
    uint16_t dktrk;		/* Track (LBA on QDD) */
    uint8_t dksec;		/* Sector number */
    uint8_t dknum;		/* Sector interleave usually 7 */
    uint8_t dksta;		/* Disk status */
#define DKS_WP		0x01
#define DKS_TRACK_ERR	0x02
#define DKS_SECTOR_ERR	0x04
#define DKS_DATA_ERR	0x08
#define DKS_NOT_READY	0x10
#define DKS_COMPARE	0x20
#define DKS_UNFORMATTED	0x40
    /* On reset set to 'C' single 'D' double */
    uint8_t *dkbuf;		/* Pointer to disk work buffer */
    uint8_t workspace[8];	/* General workspace */
    uint8_t sequce;		/* Rendering state for multi-byte accents */
    uint8_t us1;		/* Temporary storage for US escapes */
    uint8_t accent;		/* Temporary storage for accents */
    uint8_t ss2get;		/* Screen state machine for multibyte */
    uint8_t ss3get;
    uint16_t *swipt;		/* Pointer to system call table */
    uint8_t *timept;		/* Pointer to routine to run each interrupt */
    uint8_t semirq;		/* Set to non zero to re-route IRQ */
    uint8_t *irqpt;		/* Routine to run on an IRQ */
    uint16_t *firqpt;		/* Routine to run on a call to FIR (lpen) */
    uint8_t pad0;
    uint16_t smul;
    uint16_t chrptr;		/* Pointer to keyboard decoding table */
    uint16_t useraff;		/* Pointer to user font table for 128-255 */
    uint8_t latclv;		/* Keyboard repeat delay */
    uint8_t grcode;		/* Control code to set printer graphic */
    uint8_t decalg;		/* Lightpen calibration offset */
    uint8_t defdst;		/* Default disk density of current FDC */
    uint8_t dkflg;		/* Set to 0xFF if an FDC is present */
    uint8_t pad1;
    uint8_t serial[4];		/* Used by serial extension */
    uint8_t stack[76];		/* System stack */
    uint8_t lpbuf[24];		/* Light pen work buffer */
    uint8_t *fstrst;		/* Fast reset */
};

#define MON_RESET	0x00
#define MON_PUTC	0x02
#define MON_MAP_COLOR	0x04
#define MON_MAP_SHAPE	0x06
#define MON_BEEP	0x08
#define MON_GETCH	0x0A
#define MON_KTEST	0x0C
#define MON_DRAW	0x0E
#define MON_PLOT	0x10
#define MON_CHPLOT	0x12
#define MON_GETPIXEL	0x14
#define MON_LPTEST	0x16
#define MON_LPSCAN	0x18
#define MON_RDSCREEN	0x1A
#define MON_JSCAN	0x1C
#define MON_MUSIC	0x1E
#define MON_TAPE	0x20
#define MON_MOTOR	0x22
#define MON_PRINT_CTRL	0x24
#define MON_DISK_CTRL	0x26
#define MON_DISK_BOOT	0x28
#define MON_FORMAT	0x2A
#define MON_ALLOC_BLK	0x2C
#define MON_ALLOC_DIR	0x2E
#define MON_OVERWRITE	0x30
#define MON_END		0x32
#define MON_READ_FAT	0x34
#define MON_UPDATE_CLS	0x36
#define MON_OPEN	0x38
#define MON_ERASE	0x3A
