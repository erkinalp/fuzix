#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <devfd.h>
#include <devdw.h>
#include <devsys.h>
#include <devlpr.h>
#include <tty.h>
#include <vt.h>
#include <ttydw.h>
#include <devtty.h>
#include <tinydisk.h>
#include <tinyide.h>
#include <devsdc.h>
#include <device.h>

/* Device drive switch table */
struct devsw dev_tab[] =
{
	/* minor: open  close           read            write           ioctl    */
	/* --------------------------------------------------------------------- */
	/* 0: /dev/hd           Hard disc block devices (tinydisk) */
#ifdef CONFIG_TINYDISK
        {  td_open,     no_close,       td_read,        td_write,       td_ioctl  },
#else
	{  nxio_open,   no_close,       no_rdwr,        no_rdwr,        no_ioctl  },
#endif
	/* 1: /dev/fd           Floppy disc block devices  */
	{  fd_open,     no_close,       fd_read,        fd_write,       no_ioctl  },
	/* 2: /dev/tty          TTY devices */
	{  tty_open,    my_tty_close,   tty_read,       tty_write,      gfx_ioctl },
	/* 3: /dev/lpr          Printer devices */
	{  lpr_open,    lpr_close,      no_rdwr,        lpr_write,      no_ioctl  },
	/* 4: /dev/mem etc.     System devices (one offs) */
	{  no_open,     no_close,       sys_read,       sys_write,      sys_ioctl },
	/* Pack to 7 with nxio if adding private devices and start at 8 */
#ifdef CONFIG_DRIVEWIRE
	{  nxio_open,   no_close,       no_rdwr,        no_rdwr,        no_ioctl  },
	{  nxio_open,   no_close,       no_rdwr,        no_rdwr,        no_ioctl  },
	{  nxio_open,   no_close,       no_rdwr,        no_rdwr,        no_ioctl  },
	/* 8: /dev/dw           DriveWire remote disk images */
	{  dw_open,     no_close,       dw_read,        dw_write,       dw_ioctl  },
#endif
};

bool validdev(uint16_t dev)
{
	/* This is a bit uglier than needed but the right hand side is
	   a constant this way */
	if (dev > ((sizeof(dev_tab)/sizeof(struct devsw)) << 8) - 1)
		return false;
	else
		return true;
}
