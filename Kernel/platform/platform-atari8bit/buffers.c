#include <kernel.h>
#include <kdata.h>
#include <printf.h>

/*
 *	We provide a clone of the usual tmpbuf code as we carefully keep
 *	all the execve code and user copy code in the same bank
 */

/*
 * Allocate a buffer for scratch use by the kernel. This buffer can then
 * be freed with tmpfree. We will be given a buffer where bp->__bf_data
 * points to a page in our bank only accessible in our bank. This requires
 * care we put all users of tmpbuf into this bank (exec16, exec, user copy)
 */
void *tmpbuf(void)
{
	register bufptr bp;
	extern uint16_t bufclock;

	bp = freebuf();
	bp->bf_dev = NO_DEVICE;
	bp->bf_time = ++bufclock;	/* Time stamp it */
	return bp->__bf_data;
}

void tmpfree(void *p)
{
	brelse(p);
}

/* We put the helpers in overlay4 specifically so they are safe to use this
   way */
void blktok(void *kaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    memcpy(kaddr, buf->__bf_data + off, len);
}

void blkfromk(void *kaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    memcpy(buf->__bf_data + off, kaddr, len);
}

/*
 *	This works because our uput and uget (see trs80-bank.S) switch
 *	to kernel logical bank 2 when copying, as kernel bank 1 is only
 *	code so it knows that any copy must be to common or bank 2. Without
 *	that this would need a double buffer.
 */
void blktou(void *uaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    _uput(buf->__bf_data + off, uaddr, len);
}

void blkfromu(void *uaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    _uget(uaddr, buf->__bf_data + off , len);
}

static uint8_t scratchbuf[64];

/* Worst case is needing to copy over about 64 bytes */
void *blkptr(struct blkbuf *buf, uint16_t offset, uint16_t len)
{
    if (len > 64)
        panic("blkptr");
    memcpy(scratchbuf, buf->__bf_data + offset, len);
    return scratchbuf;
}

void blkzero(struct blkbuf *buf)
{
    memset(buf->__bf_data, 0, BLKSIZE);
}

extern uint8_t bufdata[];

/* This is called at start up to assign data to the first buffers, and then
   again to assign data to the extra allocated buffers */

static bufptr bnext = bufpool;
uint8_t *bdnext = bufdata;

void bufsetup(void)
{
    bufptr bp;

    for(bp = bnext; bp < bufpool_end; ++bp) {
        bp->__bf_data = bdnext;
        bdnext += BLKSIZE;
    }
    bnext = bp;
}
