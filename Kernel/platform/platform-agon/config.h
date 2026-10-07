/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Multiple processes in memory at once */
#define CONFIG_MULTI

/* Fixed banks: kernel in 04, processes in 05-0B, internal RAM as common */
#define CONFIG_BANK_FIXED
#define MAX_MAPS	7
#define CONFIG_BANKS	1
#define MAP_SIZE	0xE000U

/* Permit large I/O requests to bypass cache and go direct to userspace */
#define CONFIG_LARGE_IO_DIRECT(x)	1

#define TICKSPERSEC 100	    /* Ticks per second */

#define PROGBASE    0x0000  /* also data base */
#define PROGLOAD    0x0100  /* also data base */
#define PROGTOP     0xDE00  /* Top of program, base of U_DATA stash */
#define PROC_SIZE   56	    /* Memory needed per process including stash */

#define CMDLINE	NULL
#define BOOTDEVICENAMES "hd#"

#define CONFIG_DYNAMIC_BUFPOOL /* we expand bufpool to overwrite the _DISCARD segment at boot */
#define NBUFS    5        /* Number of block buffers. Must match kernelu.def */
#define NMOUNTS	 4	  /* Number of mounts at a time */

/* SD card support */
#define CONFIG_TD_NUM	1
#define CONFIG_TD_SD

/* tty1 is the VDP on UART0 */
#define NUM_DEV_TTY 1
#define BOOT_TTY (512 + 1)
#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */
#define TTY_INIT_BAUD B115200

#define plt_copyright()
