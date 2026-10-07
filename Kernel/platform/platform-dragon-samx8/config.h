/*
 * For the most part, feature selection is done in the Makefile, which adds
 * flags to the compiler command lines where appropriate.
 *
 * This file should primarily be used to configure common aspects specific to
 * this platform.
 */

/*** Debug options ***/

/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL

/*** Platform options ***/

/* Multiple processes in memory at once */
#define CONFIG_MULTI

/* Pure swap */
#undef CONFIG_SWAP_ONLY

/* 16K flexible banking */
#define CONFIG_BANK16
#define CONFIG_BANKS    3       /* 3 * 16K banks in CPU address space */
#define MAX_MAPS        (32-CONFIG_BANKS-1)     /* 32 - kernel (3) - video & COMMON (1) */
#define MAPBASE         0x0000

/* Standard virtual terminal core based upon VT52 emulation. */
#define CONFIG_VT
#define CONFIG_VT_MULTI
#define MAX_VT          3       /* 1 graphics, 2 text */
#define VT_RIGHT        (vt_tright[curtty])
#define VT_BOTTOM       (vt_tbottom[curtty])
#define VT_INITIAL_LINE 0
#define CONFIG_FONT8X8

/* Swap */
#define CONFIG_DYNAMIC_SWAP
#define SWAPDEV     (swap_dev)  /* To be determined */

/*** See Makefile for block device selection. ***/

/*** Basic system parameters ***/

#define TICKSPERSEC     10      /* clock rate */
#define PROGBASE        0x0100  /* low memory address for applications */
#define PROGLOAD        0x0100  /* == PROGBASE (?) */
#define PROGTOP         0xf000  /* first byte above main memory */

/* Note, we use the COMMON flag of the SAMx8 to provide a fixed common code
 * area 0xf000--0xfeff, making the maximum process size 60K.
 *
 * This gives us always-resident interrupt and syscall (SWI) handlers.  A
 * modifiable CPU vector area means we don't need to mess about with the Dragon
 * BASIC hooks at 0x0100+.
 *
 * Per-process udata is stashed "behind" this in the equivalent area of the 16K
 * page mapped to the process.
 */

#if !defined(BOOT_TTY)
#define BOOT_TTY        (512 + 1)       /* first tty device */
#endif

#if !defined(CMDLINE)
#define CMDLINE NULL    /* Location of root dev name */
#endif

#define NUM_DEV_TTY     7       /* Console, VC, 2 * reserved, ACIA, DW VSER, DW VWIN */
#define TTYDEV  BOOT_TTY        /* Device used by kernel for messages, panics */

#define NBUFS   5               /* Number of block buffers at boot time */

#define NMOUNTS 2               /* Number of mounts at a time */

/*** Swap ***/

#define SWAPBASE    0x0000      /* We swap the lot, including stashed uarea */
#define SWAPTOP     0xf200      /* so it's a round number of 256 byte sectors */
#define SWAP_SIZE   0x79        /* 60K in 512 byte blocks + udata */
#define MAX_SWAPS   32

/*** Video ***/

/* Video RAM resides at 0x7c000 (page 31), before the COMMON area.  It is
 * mapped to bank 3 (0xc000--0xfeff) for manipulation.
 *
 * Keep these in sync with kernel.def!
 */

/* Bank used to manipulate video */
#define VBANKV          31      /* use page 31 for video */
#define KBANKV          3       /* map to bank 3 to manipulate */
/* tty1 is a 6K bitmap graphics screen */
#define VIDEO_BASE      0xc000  /* which is 0xc000-0xfeff */
#define VIDEO_END       (VIDEO_BASE+0x1800)
#define VIDEO_FREG      (VBANKV*512)
/* tty3 & tty4 are 512 byte text screens */
#define VC_FREG         (VIDEO_FREG+192)
#define VC_BASE         VIDEO_END

/* At some point, we want to support the addition of a SuperSprite FM+ */
#ifndef SSFM_BASE
#define SSFM_BASE       0xff56  /* 0xff56 = MPI Compliant, 0xff76 = Native */
#endif
#define YM2413_BASE     (SSFM_BASE+0)
#define V9958_BASE      (SSFM_BASE+2)
#define YM2149_BASE     (SSFM_BASE+6)

/*** Buffers ***/

/* Permit large I/O requests to bypass cache and go direct to userspace */
#define CONFIG_LARGE_IO_DIRECT(x)       1

/* Reclaim the discard space for buffers */
#define CONFIG_DYNAMIC_BUFPOOL

/*** Block devices ***/

/* Note: blkdev and tinydisk are mutually exclusive! */

/* Maximum number of blkdev devices. */
#define MAX_BLKDEV      4

/* Maximum number of tinydisk devices. */
#define CONFIG_TD_NUM   4

/* CoCoSDC tinydisk options */
#define CONFIG_SDC_DRAGONDOS    /* set for CoCoSDC DragonDOS registers */

/*** Miscellaneous ***/

#define CONFIG_INPUT            /* Input device for joystick */
#define CONFIG_INPUT_GRABMAX    3

/* Drivewire */
#define DW_VSER_NUM 1     /* No of Virtual Serial Ports */
#define DW_VWIN_NUM 1     /* No of Virtual Window Ports */
#define DW_MIN_OFF  6     /* Minor number offset = first DW ttyX */

#define swap_map(x) ((uint8_t *)(x & 0x3fff))

/* Both of these are provided: */
#undef plt_discard
#undef plt_copyright

#define BOOTDEVICENAMES "hd#,fd#,,,,,,,dw"
