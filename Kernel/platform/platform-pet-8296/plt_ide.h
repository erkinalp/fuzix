#define ide_select(x)
#define ide_deselect()

#define IDE_IS_MMIO
#define IDE_8BIT_ONLY

#define IDE_DRIVE_COUNT 1

#define IDE_REG_DATA		0xFF80
#define IDE_REG_ERROR		0xFF81
#define IDE_REG_FEATURES	0xFF81
#define IDE_REG_SEC_COUNT	0xFF82
#define IDE_REG_LBA_0		0xFF83
#define IDE_REG_LBA_1		0xFF84
#define IDE_REG_LBA_2		0xFF85
#define IDE_REG_LBA_3		0xFF86
#define IDE_REG_DEVHEAD		0xFF86
#define IDE_REG_COMMAND		0xFF87
#define IDE_REG_STATUS		0xFF87
