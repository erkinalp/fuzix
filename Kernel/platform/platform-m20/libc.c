#include <kernel.h>
#include <kdata.h>
#include <printf.h>

extern void outchar(uint_fast8_t c);

void *memcpy(void *d, const void *s, size_t sz)
{
  unsigned char *dp = d;
  const unsigned char *sp = s;
  while(sz--)
    *dp++=*sp++;
  return d;
}

void *memset(void *d, int c, size_t sz)
{
  unsigned char *p = d;
  while(sz--)
    *p++ = c;
  return d;
}

size_t strlen(const char *p)
{
  const char *e = p;
  while(*e++);
  return e-p-1;
}

/* kputchar is used by kprintf - outputs via outchar */
void kputchar(uint_fast8_t c)
{
	if (c == '\n')
		outchar('\r');
	outchar(c);
}

/* CPU type detection - nothing to detect on Z8001 */
void set_cpu_type(void)
{
}

/*
 *	Relocate a flat binary — same approach as 68000 port.
 *	See Kernel/lib/68000relocate.c
 *
 *	Relocation entries are 32-bit offsets from the start of the
 *	loaded image (including the 0x20 VDSO area). The binary must
 *	have 0x20 bytes of VDSO placeholder at text[0..0x1F] so that
 *	relocation offsets naturally include the 0x20 prefix.
 *
 *	For Z8001 segmented mode, the value at each reloc point is a
 *	segmented address linked at base 0 (segment 0, 0x8000xxxx).
 *	We need to add the load base to get the actual address.
 */
unsigned plt_relocate(struct exec *bf)
{
	uint32_t *rp = (uint32_t *)(udata.u_database + bf->a_data);
	uint32_t n = bf->a_trsize / sizeof(uint32_t);
	uint32_t codebase = udata.u_codebase;
	uint32_t database = udata.u_database;
	uint32_t relend = bf->a_text + bf->a_data;

	while (n--) {
		uint32_t *mp;
		uint32_t mv;
		uint32_t v = _ugetl(rp++);
		if (v > relend - 3)
			return 1;
		if (v <= bf->a_text - 3)
			mp = (uint32_t *)(codebase + v);
		else if (v >= bf->a_text)
			mp = (uint32_t *)(database + v - bf->a_text);
		else
			return 1;
		/* Read the value, add the base */
		mv = _ugetl(mp);
		if (mv >= bf->a_text)
			mv += database - bf->a_text;
		else
			mv += codebase;
		_uputl(mv, mp);
	}
	return 0;
}

int memcmp(const void *a, const void *b, size_t n)
{
  const uint8_t *ap = a;
  const uint8_t *bp = b;
  while(n--) {
    if (*ap != *bp)
      return (*ap < *bp) ? -1 : 1;
    ap++;
    bp++;
  }
  return 0;
}
