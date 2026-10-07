#ifndef __DEVSDC_DOT_H__
#define __DEVSDC_DOT_H__

#ifdef CONFIG_SDC_DRAGONDOS
/* CoCoSDC/DragonDOS register layout */
# define SDC_REG_BASE 0xff48
# define SDC_CMD_BASE 0xff40
# define SDC_LBA_MODE 0x0b
#else
/* CoCoSDC/RSDOS register layout */
# define SDC_REG_BASE 0xff40
# define SDC_CMD_BASE 0xff48
# define SDC_LBA_MODE 0x43
#endif

#define SDC_REG_CTL    (SDC_REG_BASE+0)
#define SDC_REG_DATA   (SDC_REG_BASE+2)
#define SDC_REG_FCTL   (SDC_REG_BASE+3)
#define SDC_REG_CMD    (SDC_CMD_BASE+0)
#define SDC_REG_STAT   (SDC_CMD_BASE+0)
#define SDC_REG_PARAM1 (SDC_CMD_BASE+1)
#define SDC_REG_PARAM2 (SDC_CMD_BASE+2)
#define SDC_REG_PARAM3 (SDC_CMD_BASE+3)

#define SDC_BUSY  0x01
#define SDC_READY 0x02
#define SDC_FAIL  0x80

#define sdc_reg_ctl *((volatile uint8_t *)SDC_REG_CTL)
#define sdc_reg_data *((volatile uint8_t *)SDC_REG_DATA)
#define sdc_reg_fctl *((volatile uint8_t *)SDC_REG_FCTL)
#define sdc_reg_cmd *((volatile uint8_t *)SDC_REG_CMD)
#define sdc_reg_stat *((volatile uint8_t *)SDC_REG_STAT)
#define sdc_reg_param1 *((volatile uint8_t *)SDC_REG_PARAM1)
#define sdc_reg_param2 *((volatile uint8_t *)SDC_REG_PARAM2)
#define sdc_reg_param3 *((volatile uint8_t *)SDC_REG_PARAM3)

void devsdc_read(unsigned char *addr);
void devsdc_write(unsigned char *addr);
void devsdc_probe(void);

/* Shared with function in discard: */

int sdc_xfer(uint_fast8_t dev, bool is_read, uint32_t lba, uint8_t * dptr);

#endif
