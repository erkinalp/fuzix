/*
 *	Olivetti M20 platform configuration
 *
 *	Z8001 @ 4 MHz, 512 KB RAM (128 KB base + 3x128 KB expansion)
 *	Fixed mapping PROMs (no dynamic MMU)
 */

/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL

/*
 *	Memory model: we have no dynamic MMU, just fixed mapping PROMs.
 *	All processes share the same physical address space.
 */
#define CONFIG_32BIT
#define CONFIG_MULTI
#define CONFIG_FLAT
#define CONFIG_BLKBUF_HELPERS
#define CONFIG_PARENT_FIRST
#define CONFIG_BANKS	(65536/512)

/* Disabled: HD driver doesn't support rawflag=1 (direct I/O) yet */
/* #define CONFIG_LARGE_IO_DIRECT(x)	1 */

#define CONFIG_SPLIT_UDATA
#define CONFIG_STACKSIZE 2048
#define UDATA_SIZE	2048
#define UDATA_BLKS	4

/*
 *	Timer: NVI driven by i8253 Counter 2
 *	Input clock: 1.230782 MHz
 *	We configure for ~50 Hz tick rate
 */
#define TICKSPERSEC 50

#define BOOT_TTY (512 + 1)	/* First TTY device (serial port) */

#define CMDLINE	"hda"

/* Device parameters */
#define NUM_DEV_TTY 1		/* CRT display + keyboard */
#define TTYDEV   BOOT_TTY

#define NBUFS    16		/* Number of block buffers */
#define NMOUNTS	 4		/* Number of mounts at a time */

#define MAX_BLKDEV 2		/* Floppy + hard disk */

/* We have an FD1797 floppy controller */
/* We may have a WD1010 hard disk controller */

#define CONFIG_RTC		/* No RTC chip, but we track time via timer */

#define plt_copyright()

/* Process table sizes */
#define PTABSIZE	8
#define OFTSIZE		24
#define ITABSIZE	40
#define UFTSIZE		16

#define BOOTDEVICENAMES "hd#,fd#"
#define BOOTDEVICE	0x0000		/* hd0 = major 0, minor 0 */

#define TTY_INIT_BAUD	B9600
