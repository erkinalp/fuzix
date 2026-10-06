/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Acct syscall support */
#undef CONFIG_ACCT
/* Multiple processes in memory at once */
#define CONFIG_MULTI

#define DEBUG 1

#define CONFIG_BANK_FIXED 1
#define CONFIG_BANKS	1  

/* Permit large I/O requests to bypass cache and go direct to userspace */
#define CONFIG_LARGE_IO_DIRECT(x)	1

#define CONFIG_CALL_R2L		/* Runtime stacks arguments backwards */

/*
 *	64k + 2x32k RAM (swap yet to do )
 *  common is bottom on this platform
 */
#define MAX_MAPS 	2   /* 2 x 32K */
#define MAP_SIZE    0x8000

#define TICKSPERSEC 60	    /* Ticks per second */


/*#define SWAPDEV (swap_dev)	/* Dynamic swap */
/*#define SWAP_SIZE   0x40	/* 32K in 512 byte blocks */
/*#define SWAPBASE    0x8000	/* We swap the lot, including stashed uarea */
/*#define SWAPTOP     0xFF00	/* so it's a round number of 256 byte sectors */
/*#define MAX_SWAPS   32
/*#define CONFIG_DYNAMIC_SWAP*/

#define swap_map(x)	((uint8_t *)(x))

/* Permit large I/O requests to bypass cache and go direct to userspace */
/*#define CONFIG_LARGE_IO_DIRECT(x)	1*/

/* Reclaim the discard space for buffers */
/*#define CONFIG_DYNAMIC_BUFPOOL*/

#define IO_PEEK_ENABLE *((volatile uint8_t *)0xfff0) = 0x40
#define IO_PEEK_DISABLE *((volatile uint8_t *)0xfff0) = 0x00


/* We've not yet made the rest of the code - eg tricks match this ! */
#define PROGBASE    0x8000  /* also data base */
#define PROGLOAD    0x8000
#define PROGTOP     0xFE00

#define CONFIG_IDE
#define MAX_BLKDEV 1

/* FIXME: swap */

#define CONFIG_VT

#define BOOT_TTY 513        /* Set this to default device for stdio, stderr */

/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */

/* Device parameters */
#define NUM_DEV_TTY 1
#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */

#define NBUFS    5        /* Number of block buffers */
#define NMOUNTS	 2	  /* Number of mounts at a time */

extern void *memmove(void *dest, const void *src, size_t n);

// we have a 80x25 text mode display at 0x8000
#define CONFIG_VT_SIMPLE
#define VT_BASE ((uint8_t *)0x8000)
#define VT_WIDTH 80
#define VT_RIGHT 80
#define VT_BOTTOM 25

#define VT_MAP_CHAR(x)  vt_map_petscii(x)

#define plt_discard()
#define plt_copyright() kputs("Commdore 8296 Version\r")

#define BOOTDEVICENAMES "hd#"
