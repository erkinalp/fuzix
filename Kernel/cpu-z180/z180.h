#ifndef __Z180_DOT_H__
#define __Z180_DOT_H__

void copy_and_map_proc(uint16_t *pageptr);

/* irqvector values */
#define Z180_INT_UNUSED     0xFF
#define Z180_INT0           0
#define Z180_INT1           1
#define Z180_INT2           2
#define Z180_INT_TIMER0     3
#define Z180_INT_TIMER1     4
#define Z180_INT_DMA0       5
#define Z180_INT_DMA1       6
#define Z180_INT_CSIO       7
#define Z180_INT_ASCI0      8
#define Z180_INT_ASCI1      9

#define TIME_TMDR0L	Z180_IO_BASE + 0x0C	/* Timer data register,    channel 0L         */
#define TIME_MODR0H	Z180_IO_BASE + 0x0D	/* Timer data register,    channel 0H         */
#define TIME_RLDR0L	Z180_IO_BASE + 0x0E	/* Timer reload register,  channel 0L         */
#define TIME_RDLR0H	Z180_IO_BASE + 0x0F	/* Timer reload register,  channel 0H         */
#define TIME_TCR	Z180_IO_BASE + 0x10	/* Timer control register                     */
#define TIME_TMDR1L	Z180_IO_BASE + 0x14	/* Timer data register,    channel 1L         */
#define TIME_TMDR1H	Z180_IO_BASE + 0x15	/* Timer data register,    channel 1H         */
#define TIME_RLDR1L	Z180_IO_BASE + 0x16	/* Timer reload register,  channel 1L         */
#define TIME_RLDR1H	Z180_IO_BASE + 0x17	/* Timer reload register,  channel 1H         */
#define TIME_FCR	Z180_IO_BASE + 0x18	/* Timer Free running counter                 */

#define ASCI_CNTLA0	Z180_IO_BASE + 0x00	/* ASCI control register A channel 0          */
#define ASCI_CNTLA1	Z180_IO_BASE + 0x01	/* ASCI control register A channel 1          */
#define ASCI_CNTLB0	Z180_IO_BASE + 0x02	/* ASCI control register B channel 0          */
#define ASCI_CNTLB1	Z180_IO_BASE + 0x03	/* ASCI control register B channel 0          */
#define ASCI_STAT0	Z180_IO_BASE + 0x04	/* ASCI status register    channel 0          */
#define ASCI_STAT1	Z180_IO_BASE + 0x05	/* ASCI status register    channel 1          */
#define ASCI_TDR0	Z180_IO_BASE + 0x06	/* ASCI transmit data reg, channel 0          */
#define ASCI_TDR1	Z180_IO_BASE + 0x07	/* ASCI transmit data reg, channel 1          */
#define ASCI_RDR0	Z180_IO_BASE + 0x08	/* ASCI receive data reg,  channel 0          */
#define ASCI_RDR1	Z180_IO_BASE + 0x09	/* ASCI receive data reg,  channel 0          */
#define ASCI_ASEXT0	Z180_IO_BASE + 0x12	/* ASCI extension register channel 0          */
#define ASCI_ASEXT1	Z180_IO_BASE + 0x13	/* ASCI extension register channel 1          */
#define ASCI_ASTC0L	Z180_IO_BASE + 0x1A	/* ASCI time constant register channel 0 low  */
#define ASCI_ASTC0H	Z180_IO_BASE + 0x1B	/* ASCI time constant register channel 0 high */
#define ASCI_ASTC1L	Z180_IO_BASE + 0x1C	/* ASCI time constant register channel 1 low  */
#define ASCI_ASTC1H	Z180_IO_BASE + 0x1D	/* ASCI time constant register channel 1 high */

#define CSIO_CNTR	Z180_IO_BASE + 0x0A	/* CSI/O control/status register              */
#define CSIO_TRDR	Z180_IO_BASE + 0x0B	/* CSI/O transmit/receive data register       */

#define Z180_RCR	Z180_IO_BASE + 0x36	/* Refresh control register */
#define Z180_OMCR	Z180_IO_BASE + 0x3E	/* Output mode control register */
#define Z180_ICR	Z180_IO_BASE + 0x3F	/* I/O control register */
#define Z180_CMR	Z180_IO_BASE + 0x1E	/* Clock multiplier register */
#define Z180_CCR	Z180_IO_BASE + 0x1F	/* Clock divide/standby register */
#define Z180_DCNTL	Z180_IO_BASE + 0x32	/* DMA/WAIT control */

/* On Z80182 the MIMIC, ESCC, PIA and MISC registers are at fixed addresses */
#define ESCC_CTRL_A	0xE0			/* ESCC Channel A control register            */
#define ESCC_DATA_A	0xE1			/* ESCC Channel A data register               */
#define ESCC_CTRL_B	0xE2			/* ESCC Channel B control register            */
#define ESCC_DATA_B	0xE3			/* ESCC Channel B data register               */

#define PORT_A_DDR	0xED			/* Port A data direction register             */
#define PORT_A_DATA	0xEE			/* Port A data register                       */
#define PORT_B_DDR	0xE4			/* Port B data direction register             */
#define PORT_B_DATA	0xE5			/* Port B data register                       */
#define PORT_C_DDR	0xDD			/* Port C data direction register             */
#define PORT_C_DATA	0xDE			/* Port C data register                       */

#endif
