/*
 *	Z8001 (segmented) CPU support for FUZIX
 */

#define CPU_MID MID_FUZIXZ8000

#define uputp  uputl			/* Pointers are 32-bit (seg:offset) */
#define ugetp(x)  ugetl(x)
#define uputi  uputw			/* int is 16-bit */
#define ugeti(x)  ugetw(x)

extern void *memcpy(void *, const void *, size_t);
extern void *memset(void *, int, size_t);
extern int memcmp(const void *, const void *, size_t);
extern size_t strlen(const char *);
extern int strcmp(const char *, const char *);

#define brk_limit() ((udata.u_syscall_sp) - 512)

#define staticfast

/* User's structure for times() system call */
typedef unsigned long clock_t;

typedef union {            /* this structure is endian dependent */
    clock_t  full;         /* 32-bit count of ticks since boot */
    struct {
      uint16_t high;
      uint16_t low;         /* 16-bit count of ticks since boot */
    } h;
} ticks_t;

extern uint16_t swab(uint16_t);

#define	ntohs(x)	(x)
#define ntohl(x)	(x)

#define cpu_to_le16(x)	le16_to_cpu(x)
#define le16_to_cpu(x)	(uint16_t)(__builtin_bswap16((uint16_t)(x)))
#define cpu_to_le32(x)	le32_to_cpu(x)
#define le32_to_cpu(x)	(uint32_t)(__builtin_bswap32((uint32_t)(x)))

/* Segmented pointers are 32-bit */
#define POINTER32

typedef	uint32_t	paddr_t;	/* 32-bit physical addresses */
typedef uint16_t	page_t;		/* Page frame numbering */

/* Sane behaviour for unused parameters */
#define used(x)

/*
 *	udata access via a register global.
 *	On Z8001 we dedicate R10 to hold the udata pointer.
 */
register struct u_data *udata_ptr asm ("r10");

#define udata (*udata_ptr)

#define BIG_ENDIAN

#ifndef CONFIG_STACKSIZE
#define CONFIG_STACKSIZE	1024
#endif

#define __packed		__attribute__((packed))
#define barrier()		asm volatile("":::"memory")

/* Memory helpers: Max of 32767 blocks (16MB) as written */
extern void copy_blocks(void *, void *, unsigned int);
extern void swap_blocks(void *, void *, unsigned int);

/*
 *	Z8001 uses separate I/O address space accessed via IN/OUT
 *	instructions, not memory-mapped I/O. The platform must provide
 *	inb/outb/inw/outw functions in assembly.
 */
extern uint8_t inb(uint16_t port);
extern void outb(uint16_t port, uint8_t val);
extern uint16_t inw(uint16_t port);
extern void outw(uint16_t port, uint16_t val);

#define in(x)		inb(x)
#define out(x,y)	outb(x,y)
#define in16(x)		inb(x)
#define out16(x,y)	outb(x,y)

/* We require word alignment */
#define UNALIGNED(x)		((x) & 1)
#define ALIGNUP(x)		(((x) + 1) & ~1)
#define ALIGNDOWN(x)		((x) & ~1)
/* Stack 16-bit aligned */
#define STACKALIGN(x)		((x) & ~1)

#define PROGBASE		(udata.u_codebase)

#define __fastcall
#define NORETURN __attribute__((__noreturn__))
