/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Multiple processes in memory at once */
#define CONFIG_MULTI
/* CP/M emulation */
#undef CONFIG_CPM_EMU
/* Fixed banking: 8 x 64K banks, top 4KB is shared with kernel, 60KB-62KB is user memory  */
#define CONFIG_BANK_SPLIT
/* Permit large I/O requests to bypass cache and go direct to userspace */
#define CONFIG_LARGE_IO_DIRECT(x)	1
/* 8 60K banks, 1 is kernel */
#define MAX_MAPS	8
#define MAP_SPLIT	PROGTOP

/* Banks as reported to user space */
#define CONFIG_BANKS	1

#define TICKSPERSEC 40U     /* Ticks per second */
#define PROGBASE    0x0000  /* also data base */
#define PROGLOAD    0x0100  /* also data base */
#define PROGTOP     0xF600  /* Top of program, base of U_DATA copy */
#define KERNTOP     0xF000  /* Kernel has lower 60KB */
#define PROC_SIZE   64      /* Memory needed per process */

/* We need a tidier way to do this from the loader */
#define CMDLINE	(0x0081)  /* Location of root dev name */
#define BOOTDEVICENAMES "hd#,,,rd"

#define CONFIG_DYNAMIC_BUFPOOL /* we expand bufpool to overwrite the _DISCARD segment at boot */
#define NBUFS    4        /* Number of block buffers, keep in line with space reserved in mark4.s */
#define NMOUNTS	 4	  /* Number of mounts at a time */

#define SWAPDEV     (swap_dev)	/* A variable for dynamic, or a device major/minor */
extern uint16_t swap_dev;
#define SWAP_SIZE   0x7D 	/* 62.5K in blocks (prog + udata) */
#define SWAPBASE    0x0000	/* start at the base of user mem */
#define SWAPTOP	    0xF800	/* Swap out udata and program */
#define MAX_SWAPS   16	    	/* We will size if from the partition */
/* Swap will be set up when a suitably labelled partition is seen */
#define CONFIG_DYNAMIC_SWAP
#define swap_map(x)	((uint8_t *)(x))

/* Hardware parameters */
#define Z180_IO_BASE       0x40
#define MARK4_IO_BASE      0x80

#define CONFIG_TD_NUM		3
/* RC2014 style CF IDE */
#define CONFIG_TD_IDE
#define CONFIG_TINYIDE_8BIT
#define CONFIG_TINYIDE_INDIRECT
#define IDE_IS_8BIT(x)		1
/* SD via CSIO : Needs an additional GPIO pin so not on all boards. */
#define CONFIG_TD_SD
#define TD_SD_NUM		1

/* On-board DS1302 on Mark IV, we can read the time of day from it */
#define CONFIG_RTC_DS1302
#define CONFIG_RTC
#define CONFIG_RTC_FULL
#define CONFIG_RTC_INTERVAL 30 /* deciseconds between reading RTC seconds counter */

/* Optional PropIOv2 board on ECB bus */
#define CONFIG_PROPIO2		/* #define CONFIG_PROPIO2 to enable as tty3 and disk */
#define PROPIO2_IO_BASE		0xA8

/* Device parameters */
#ifdef CONFIG_PROPIO2
#define NUM_DEV_TTY 3
#else
#define NUM_DEV_TTY 2
#endif
/* ASCI0 as the console. This matches the ROMWBW behaviour */
#define TTYDEV   (512+1)  /* System console (used by kernel, init) */

#define plt_copyright()
