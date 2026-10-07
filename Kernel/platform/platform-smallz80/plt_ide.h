/* GIDE at 0x30 or 0x50 */

#include "smallz80.h"

#define data	(ide_base + 0x0)
#define error	(ide_base + 0x1)
#define count	(ide_base + 0x2)
#define sec	(ide_base + 0x3)
#define cyll	(ide_base + 0x4)
#define cylh	(ide_base + 0x5)
#define devh	(ide_base + 0x6)
#define cmd	(ide_base + 0x7)
#define status	(ide_base + 0x7)

#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
