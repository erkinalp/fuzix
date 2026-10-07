/*
 *	We need some slightly odd banking arrangements for the 7/70
 *	so a custom implementation is used
 *
 *	TODO: most of this
 *	The tricky bit is that we have 5 external banks and one fixed low
 *	bank. In order to manage three processes we assign one bank to each of
 *	the processes high 16K. The low 16K is copied on switches but has to
 *	be exchanged so the second page (low byte of p_page) moves around
 *	between processes unlike normal bankfixed.c
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>

static uint16_t pfree[MAX_MAPS];
static uint_fast8_t pfptr = 0;
static uint_fast8_t pfmax;

void pagemap_add(uint16_t page)
{
	if (pfptr == MAX_MAPS)
		panic(PANIC_MAPOVER);
	pfree[pfptr++] = page;
	pfmax = pfptr;
}

void pagemap_free(ptptr p)
{
	if (p->p_page == 0)
		panic(PANIC_FREE0);
	pfree[pfptr++] = p->p_page;
}

int pagemap_alloc(ptptr p)
{
#ifdef SWAPDEV
	if (pfptr == 0) {
		swapneeded(p, 1);
	}
#endif
	if (pfptr == 0)
		return ENOMEM;
	p->p_page = pfree[--pfptr];
	return 0;
}

/* Realloc is a no-op */
int pagemap_realloc(struct exec *hdr, uint16_t size)
{
	udata.u_ptab->p_size = MAP_SIZE >> 10;
	return 0;
}

int pagemap_prepare(struct exec *hdr)
{
	/* If it is relocatable load it at PROGLOAD */
	if (hdr->a_base == 0)
		hdr->a_base = PROGLOAD >> 8;
	else if (hdr->a_base != (PROGLOAD >> 8)) {
		udata.u_error = ENOEXEC;
		return -1;
	}
	/* If it doesn't care about the size then the size is all the
	   space we have */
	if (hdr->a_size == 0)
		hdr->a_size = (ramtop >> 8) - hdr->a_base;
	/* Check it fits - we can do this early for fixed banks */
	if (hdr->a_size > (MAP_SIZE >> 8)) {
		udata.u_error = ENOMEM;
		return -1;
	}
	return 0;
}

usize_t pagemap_mem_used(void)
{
	return (pfmax - pfptr) * (MAP_SIZE >> 10);
}

#ifdef SWAPDEV
/*
 *	Swap out the memory of a process to make room
 *	for something else
 *
 *	FIXME: we can write out base - p_top, then the udata providing
 *	we also modify our read logic here as well
 */
int swapout(ptptr p)
{
	uint16_t page = p->p_page;
	uint16_t blk;
	int16_t map;

	if (!page)
		panic(PANIC_ALREADYSWAP);
	/* Are we out of swap ? */
	map = swapmap_alloc();
	if (map == -1)
		return ENOMEM;
#ifdef DEBUG
	kprintf("Swapping out %x (%d) to map %d\n", p, p->p_page, map);
#endif
	blk = map * SWAP_SIZE;
	/* Write the app (and possibly the uarea etc..) to disk */
	swapwrite(SWAPDEV, blk, SWAPTOP - SWAPBASE, SWAPBASE, p->p_page);
	pagemap_free(p);
	p->p_page = 0;
	p->p_page2 = map;
#ifdef DEBUG
	kprintf("%x: swapout done %d\n", p, p->p_page);
#endif
	return 0;
}

/*
 * Swap ourself in: must be on the swap stack when we do this
 */
void swapin(ptptr p, uint16_t map)
{
	uint16_t blk = map * SWAP_SIZE;

#ifdef DEBUG
	kprintf("Swapin %x, %d from map %d\n", p, p->p_page, map);
#endif
	if (!p->p_page) {
		kprintf("%x: nopage!\n", p);
		return;
	}
	swapread(SWAPDEV, blk, SWAPTOP - SWAPBASE, SWAPBASE, p->p_page);
#ifdef DEBUG
	kprintf("%x: swapin done %d\n", p, p->p_page);
#endif
}

#endif
