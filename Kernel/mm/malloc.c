#include <kernel.h>
#include <printf.h>

/*
 *	This is inspired by Dale Schumacher's public domain dlibs, but rewritten
 *	from scratch. It's a very simple, very compact and surprisingly efficient
 *	malloc/free/memavail
 *
 *	These functions should *not* be used by core kernel code. They are
 *	used to support flat address space machines. They can be used by 32bit
 *	specific code and drivers but care should be taken to avoid fragmentation
 *	and leaks.
 */

#if defined(CONFIG_32BIT)

static uint32_t mfree;
static uint32_t mtotal;

#undef DEBUG_MEMORY

#ifdef DEBUG_MEMORY
static void _sc(uint_fast8_t c) { while (!(in(0xC3) & 4)); out(0xC1, c); }
static void _sh(uint32_t v) {
	const char *h = "0123456789ABCDEF";
	int i; for (i = 28; i >= 0; i -= 4) _sc(h[(v >> i) & 0xF]);
}
static void _ss(const char *s) { while (*s) _sc(*s++); }
#define DBG(x) x
#else
#define DBG(x)
#endif

struct block
{
	struct block *next;
	size_t length; /* high bit set if used */
};

#define UNUSED(b) (!((b)->length & (1L<<31)))

static struct block start = { NULL, sizeof(struct block) };

/*
 * Add a memory block to the pool. Must be aligned to the alginment boundary
 * in use.
 */
void kmemaddblk(void *base, size_t size)
{
	struct block *b = &start;
	struct block *n = (struct block *) base;

	/* Run down the list until we find the last block. */

	while (b->next)
		b = b->next;

	/* Add the block. */

	b->next = n;
	n->next = NULL;
	n->length = size;
	DBG(_ss("A "); _sh((uint32_t)n); _sc('+'); _sh(n->length); _sc('\n'));
	mfree += size;
	mtotal += size;
}

/*
 * Find the smallest unused block containing at least length bytes.
 */
static struct block *find_smallest(size_t length)
{
	static struct block dummy = { NULL, 0x7fffffff };
	struct block *smallest = &dummy;
	struct block *b = &start;

	while (b)
	{
		if (UNUSED(b)
			&& (b->length >= length)
			&& (b->length < smallest->length))
		{
			smallest = b;
		}

		b = b->next;
	}

	return (smallest == &dummy) ? NULL : smallest;
}

/*
 * Split the supplied block into a used section and an unused section
 * immediately following it (if big enough).
 */
static void split_block(struct block *b, size_t size)
{
	int32_t newsize = b->length - size; /* might be negative */
	if (newsize > sizeof(struct block) * 4)
	{
		struct block *n = (struct block *)((uint8_t *)b + size);
		n->next = b->next;
		b->next = n;
		b->length = size;
		n->length = newsize;
		DBG(_ss("S "); _sh((uint32_t)b); _sc('+'); _sh(b->length);
		    _sc(' '); _sh((uint32_t)n); _sc('+'); _sh(n->length); _sc('\n'));
	}

	b->length |= 0x80000000;
}

/*
 * Allocate a block.
 */
void *kmalloc(size_t size, uint8_t owner)
{
	struct block *b;

	used(owner);	/* For now */
	size = (size_t)ALIGNUP(size) + sizeof(struct block);
	b = find_smallest(size);
	if (!b)
		return NULL;

	split_block(b, size);
	DBG(_ss("a "); _sh((uint32_t)b); _sc('+'); _sh(b->length); _sc('\n'));
	mfree -= b->length;
	return b + 1;
}

/*
 * Find the largest unused block containing at least length bytes.
 */
static struct block *find_largest(size_t length)
{
	struct block *largest = NULL;
	struct block *b = &start;

	while (b)
	{
		if (UNUSED(b)
			&& (b->length >= length)
			&& (largest == NULL || b->length > largest->length))
		{
			largest = b;
		}
		b = b->next;
	}
	return largest;
}

/*
 * Allocate from the largest free block.
 */
void *kmalloc_largest(size_t size, uint8_t owner)
{
	struct block *b;

	used(owner);
	size = (size_t)ALIGNUP(size) + sizeof(struct block);
	b = find_largest(size);
	if (!b)
		return NULL;

	split_block(b, size);
	DBG(_ss("L "); _sh((uint32_t)b); _sc('+'); _sh(b->length); _sc('\n'));
	mfree -= b->length;
	return b + 1;
}

/*
 * Merge all adjacent free blocks in the chain.
 */
static void merge_all_blocks(void)
{
	struct block *b = &start;

	while (b->next)
	{
		struct block *n = b->next;

		if (UNUSED(b)
			&& UNUSED(n)
			&& (((uint8_t*)b + b->length) == (uint8_t*)n))
		{
			/* Two mergeable blocks are adjacent. */
			b->next = n->next;
			b->length += n->length;
			DBG(_ss("M "); _sh((uint32_t)b); _sc('+'); _sh(b->length); _sc('\n'));
		}
		else
		{
			/* Only move on to the next block if we're unable to merge
			 * this one. */
			b = n;
		}
	}
}

/*
 * Free a block. If there's a block immediately after this one, merge it.
 * (This maintains ordering within split blocks.)
 */
void kfree(void *p)
{
	struct block *b = (struct block *)p - 1;

	if (p == NULL)
		return;
	DBG(_ss("F "); _sh((uint32_t)b); _sc('+'); _sh(b->length); _sc('\n'));

	if (UNUSED(b)) {
		kprintf("kfree: p=%p b=%p len=%x\n", p, b, (unsigned)b->length);
		panic(PANIC_BADFREE);
	}
	
	b->length &= 0x7fffffff;
	mfree += b->length;
	merge_all_blocks();
}

void kfree_s(void *p, size_t unused)
{
	/* FIXME: we could do length checks ? */
	kfree(p);
}

unsigned long kmemavail(void)
{
	return mfree;
}

unsigned long kmemused(void)
{
	return mtotal - mfree;
}

#endif
