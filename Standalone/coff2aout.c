/*
 *	Turn a Z8001 COFF relocatable object (from ld -r) into a
 *	FUZIX a.out flat binary with relocation table.
 *
 *	Input:  merged .o produced by z8k-coff-ld -r -T script
 *	Output: FUZIX a.out binary
 *
 *	COFF format reference: binutils include/coff/external.h, include/coff/z8k.h
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>

#include "../Kernel/include/a.out.h"

/* COFF constants from include/coff/z8k.h */
#define Z8KMAGIC	0x8000
#define F_Z8001		0x1000

/* COFF section flags */
#define STYP_TEXT	0x0020
#define STYP_DATA	0x0040
#define STYP_BSS	0x0080

/* Z8k relocation types from include/coff/z8k.h */
#define R_IMM32		0x11
#define R_IMM32_NORELAX	0x31

/* COFF structure sizes from include/coff/external.h and z8k.h */
#define FILHSZ		20
#define SCNHSZ		40
#define RELSZ		16	/* z8k-specific: 4+4+4+2+2 */

/* Read big-endian values from raw bytes */
static uint16_t get16(const uint8_t *p)
{
	return ((uint16_t)p[0] << 8) | p[1];
}

static uint32_t get32(const uint8_t *p)
{
	return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
	       ((uint32_t)p[2] << 8) | p[3];
}

#define MAX_RELOCS	32768

static uint32_t relocs[MAX_RELOCS];
static unsigned int nrelocs;

static int verbose;

static void add_reloc(uint32_t offset)
{
	if (nrelocs >= MAX_RELOCS) {
		fprintf(stderr, "coff2aout: too many relocations (%u)\n", nrelocs);
		exit(1);
	}
	relocs[nrelocs++] = htonl(offset);
}

static void die(const char *msg)
{
	fprintf(stderr, "coff2aout: %s\n", msg);
	exit(1);
}

int main(int argc, char **argv)
{
	const char *infile = NULL;
	const char *outfile = NULL;
	int stacksize = 1024;
	FILE *fp, *ofp;
	uint8_t *buf;
	long fsize;
	int opt;

	while ((opt = getopt(argc, argv, "o:s:v")) != -1) {
		switch (opt) {
		case 'o':
			outfile = optarg;
			break;
		case 's':
			stacksize = strtol(optarg, NULL, 0);
			break;
		case 'v':
			verbose = 1;
			break;
		default:
			fprintf(stderr, "usage: coff2aout [-v] [-s stacksize] -o output input.o\n");
			exit(1);
		}
	}
	if (!outfile || optind != argc - 1) {
		fprintf(stderr, "usage: coff2aout [-v] [-s stacksize] -o output input.o\n");
		exit(1);
	}
	infile = argv[optind];

	/* Read entire COFF file */
	fp = fopen(infile, "rb");
	if (!fp) { perror(infile); exit(1); }
	fseek(fp, 0, SEEK_END);
	fsize = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	buf = malloc(fsize);
	if (!buf) die("out of memory");
	if (fread(buf, 1, fsize, fp) != (size_t)fsize)
		die("short read");
	fclose(fp);

	/* Parse COFF file header */
	if (fsize < FILHSZ)
		die("file too small");
	uint16_t f_magic = get16(buf + 0);
	uint16_t f_nscns = get16(buf + 2);
	/* f_timdat at 4 */
	/* f_symptr at 8 */
	/* f_nsyms at 12 */
	uint16_t f_opthdr = get16(buf + 16);
	uint16_t f_flags = get16(buf + 18);

	if (f_magic != Z8KMAGIC)
		die("not a Z8K COFF file");
	if (!(f_flags & F_Z8001))
		die("not a Z8001 (segmented) COFF file");

	/* Section headers start after file header + optional header */
	uint32_t shoff = FILHSZ + f_opthdr;

	/* Find .text, .data, .bss sections */
	uint32_t text_size = 0, text_scnptr = 0;
	uint32_t text_relptr = 0;
	uint16_t text_nreloc = 0;
	uint32_t data_size = 0, data_scnptr = 0;
	uint32_t data_relptr = 0;
	uint16_t data_nreloc = 0;
	uint32_t bss_size = 0;
	int has_text = 0, has_data = 0, has_bss = 0;

	for (int i = 0; i < f_nscns; i++) {
		uint32_t off = shoff + i * SCNHSZ;
		if (off + SCNHSZ > (uint32_t)fsize)
			die("section header beyond EOF");
		uint8_t *sh = buf + off;
		/* char s_name[8] at 0 */
		/* s_paddr at 8, s_vaddr at 12, s_size at 16 */
		/* s_scnptr at 20, s_relptr at 24, s_lnnoptr at 28 */
		/* s_nreloc at 32, s_nlnno at 34, s_flags at 36 */
		/* uint32_t s_vaddr = get32(sh + 12); — unused, VMAs are 0 in -r output */
		uint32_t s_size = get32(sh + 16);
		uint32_t s_scnptr = get32(sh + 20);
		uint32_t s_relptr = get32(sh + 24);
		uint16_t s_nreloc = get16(sh + 32);
		uint32_t s_flags = get32(sh + 36);

		if (verbose) {
			char name[9];
			memcpy(name, sh, 8);
			name[8] = 0;
			printf("section %-8s size=0x%04x scnptr=0x%04x "
			       "relptr=0x%04x nreloc=%u flags=0x%08x\n",
			       name, s_size, s_scnptr,
			       s_relptr, s_nreloc, s_flags);
		}

		if (memcmp(sh, ".text\0\0\0", 8) == 0) {
			text_size = s_size;
			text_scnptr = s_scnptr;
			text_relptr = s_relptr;
			text_nreloc = s_nreloc;
			has_text = 1;
		} else if (memcmp(sh, ".data\0\0\0", 8) == 0) {
			data_size = s_size;
			data_scnptr = s_scnptr;
			data_relptr = s_relptr;
			data_nreloc = s_nreloc;
			has_data = 1;
		} else if (memcmp(sh, ".bss\0\0\0\0", 8) == 0) {
			bss_size = s_size;
			has_bss = 1;
		}
	}

	if (!has_text)
		die("no .text section");

	/* Build memory image: text + data contiguous.
	 * In a relocatable .o, VMAs are all 0. Layout by sizes. */
	uint32_t a_text = text_size;
	uint32_t a_data = has_data ? data_size : 0;
	uint32_t a_bss = has_bss ? bss_size : 0;
	uint32_t image_size = a_text + a_data;

	uint8_t *image = calloc(1, image_size);
	if (!image) die("out of memory");

	/* Copy text section at offset 0 */
	if (text_scnptr && text_size) {
		if (text_scnptr + text_size > (uint32_t)fsize)
			die(".text data beyond EOF");
		memcpy(image, buf + text_scnptr, text_size);
	}

	/* Copy data section right after text */
	if (has_data && data_scnptr && data_size) {
		if (data_scnptr + data_size > (uint32_t)fsize)
			die(".data data beyond EOF");
		memcpy(image + a_text, buf + data_scnptr, data_size);
	}

	/* Read COFF symbol table for fixing relocation values.
	 * The ld -r output has correct symbol addresses but
	 * incorrect instruction values (double-counted offsets).
	 * We re-apply the correct symbol values ourselves. */
	uint32_t symoff = get32(buf + 8);	/* f_symptr */
	uint32_t nsyms = get32(buf + 12);	/* f_nsyms */

	/* Process relocations: R_IMM32 from .text and .data */
	for (int i = 0; i < text_nreloc; i++) {
		uint32_t roff = text_relptr + i * RELSZ;
		if (roff + RELSZ > (uint32_t)fsize)
			die("relocation beyond EOF");
		uint8_t *rp = buf + roff;
		uint32_t r_vaddr = get32(rp + 0);
		uint32_t r_symndx = get32(rp + 4);
		uint32_t r_offset = get32(rp + 8);  /* addend */
		uint16_t r_type = get16(rp + 12);
		/* r_stuff at 14 */

		if (r_type == R_IMM32 || r_type == R_IMM32_NORELAX) {
			if (r_symndx >= nsyms)
				die("relocation symbol index out of range");
			/* Read symbol: 18 bytes each (SYMESZ) */
			uint8_t *sym = buf + symoff + r_symndx * 18;
			uint32_t sym_value = get32(sym + 8) + r_offset;
			/* Write correct flat value into image */
			uint32_t final_offset = r_vaddr;
			if (final_offset + 3 >= image_size)
				die("relocation offset out of range");
			image[final_offset]     = (sym_value >> 24) & 0xff;
			image[final_offset + 1] = (sym_value >> 16) & 0xff;
			image[final_offset + 2] = (sym_value >> 8) & 0xff;
			image[final_offset + 3] = sym_value & 0xff;
			if (verbose)
				printf("  reloc @0x%04x sym[%u]=0x%08x\n",
				       final_offset, r_symndx, sym_value);
			add_reloc(final_offset);
		} else if (verbose) {
			printf("  skip reloc @0x%04x type 0x%02x\n", r_vaddr, r_type);
		}
	}

	/* Process relocations from .data section */
	for (int i = 0; i < data_nreloc; i++) {
		uint32_t roff = data_relptr + i * RELSZ;
		if (roff + RELSZ > (uint32_t)fsize)
			die("data relocation beyond EOF");
		uint8_t *rp = buf + roff;
		uint32_t r_vaddr = get32(rp + 0);
		uint32_t r_symndx = get32(rp + 4);
		uint32_t r_offset = get32(rp + 8);  /* addend */
		uint16_t r_type = get16(rp + 12);

		if (r_type == R_IMM32 || r_type == R_IMM32_NORELAX) {
			if (r_symndx >= nsyms)
				die("data relocation symbol index out of range");
			uint8_t *sym = buf + symoff + r_symndx * 18;
			uint32_t sym_value = get32(sym + 8) + r_offset;
			/* Data reloc vaddr is already absolute (includes text offset)
			 * because the linker script places .data at SIZEOF(.text) */
			uint32_t final_offset = r_vaddr;
			if (final_offset + 3 >= image_size)
				die("data relocation offset out of range");
			image[final_offset]     = (sym_value >> 24) & 0xff;
			image[final_offset + 1] = (sym_value >> 16) & 0xff;
			image[final_offset + 2] = (sym_value >> 8) & 0xff;
			image[final_offset + 3] = sym_value & 0xff;
			if (verbose)
				printf("  data reloc @0x%04x sym[%u]=0x%08x\n",
				       final_offset, r_symndx, sym_value);
			add_reloc(final_offset);
		}
	}

	if (verbose)
		printf("a_text=0x%x a_data=0x%x a_bss=0x%x relocs=%u\n",
		       a_text, a_data, a_bss, nrelocs);

	/* Write a.out */
	ofp = fopen(outfile, "wb");
	if (!ofp) { perror(outfile); exit(1); }

	struct exec ah;
	memset(&ah, 0, sizeof(ah));
	ah.a_midmag = htonl((MID_FUZIXZ8000 << 16) | NMAGIC);
	ah.a_text = htonl(a_text);
	ah.a_data = htonl(a_data);
	ah.a_bss = htonl(a_bss);
	ah.a_syms = 0;
	ah.a_entry = htonl(0x0020);	/* entry at text[0x20], after VDSO */
	ah.a_trsize = htonl(nrelocs * 4);
	ah.a_drsize = 0;
	ah.stacksize = htonl(stacksize);

	/* Write 64-byte header */
	if (fwrite(&ah, sizeof(ah), 1, ofp) != 1)
		die("write error (header)");

	/* Write text+data starting at 0x20 (skip VDSO placeholder).
	 * The exec loader reads a_text - 0x20 bytes for text,
	 * then a_data bytes for data. */
	if (fwrite(image + 0x20, image_size - 0x20, 1, ofp) != 1)
		die("write error (image)");

	/* Write relocation table */
	if (nrelocs > 0) {
		if (fwrite(relocs, sizeof(uint32_t), nrelocs, ofp) != nrelocs)
			die("write error (relocs)");
	}

	fclose(ofp);

	printf("%s: %u bytes, a_text=0x%x a_data=0x%x a_bss=0x%x "
	       "%u relocs\n", outfile, (unsigned)(sizeof(ah) + image_size - 0x20 + nrelocs * 4),
	       a_text, a_data, a_bss, nrelocs);

	free(image);
	free(buf);
	return 0;
}
