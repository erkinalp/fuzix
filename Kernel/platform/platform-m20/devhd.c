/*
 *	Olivetti M20 hard disk driver via BIOS ROM disk_io
 *
 *	Uses the BIOS ROM call at 0x84000068 for all HD I/O.
 *	Physical sector size is 256 bytes; FUZIX uses 512-byte blocks.
 *	Each FUZIX block = 2 physical sectors.
 *
 *	The HD image layout reserves sectors 0-383 for boot structures
 *	and the kernel. The FUZIX filesystem starts at a configurable
 *	sector offset (HD_OFFSET).
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devhd.h>

/* Sector offset for FUZIX filesystem on the HD image.
   Must match mkm20hd.py's filesystem start sector.  */
#define HD_OFFSET	384

/* BIOS disk_io: implemented in m20.S */
extern int hd_biosio(uint16_t dev_op, uint16_t count, uint16_t sector, void *buf);

static int hd_transfer(bool is_read, uint_fast8_t minor, uint_fast8_t rawflag)
{
	uint16_t ct;
	int err;

	if (rawflag)
		goto bad2;

	/* Each FUZIX 512-byte block = 2 physical 256-byte sectors */
	ct = 2;
	err = hd_biosio(
		is_read ? 0x0A00 : 0x0A01,	/* device 0x0A (HD), op 0=read/1=write */
		ct,
		(udata.u_block << 1) + HD_OFFSET,
		udata.u_buf->__bf_data
	);

	if (err) {
		volatile uint8_t *bios = (volatile uint8_t *)0x82000000UL;
		kprintf("hd: err %d blk %d sec %d\n",
			err, udata.u_block,
			(udata.u_block << 1) + HD_OFFSET);
		kprintf("  BIOS: dev=%x op=%x err=%x xerr=%x\n",
			bios[0x12], bios[0x13], bios[0x0e], bios[0x0f]);
		goto bad;
	}
	return ct << 8;	/* 512 bytes transferred */

bad:
	udata.u_error = EIO;
bad2:
	return -1;
}

int hd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return hd_transfer(true, minor, rawflag);
}

int hd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return hd_transfer(false, minor, rawflag);
}

int hd_open(uint_fast8_t minor, uint16_t flag)
{
	flag;
	if (minor != 0) {
		udata.u_error = ENODEV;
		return -1;
	}
	/* Ensure BIOS knows HD is present.
	   The bootloader already used the HD, but SYS_HDPRES at
	   <<2>>:0x34 may have been cleared.  */
	*(volatile uint8_t *)0x82000034UL = 1;
	return 0;
}
