extern uint8_t ps2kbd_present;
extern uint8_t ps2mouse_present;

/* For now */
extern void spi_select_port(uint8_t n);
#define spi_select_none()	spi_select_port(7)

#define spi_send	sd_spi_transmit_byte
#define spi_recv	sd_spi_receive_byte

/* Mini-ITX 82C55 */
#define PPI_A		0x40
#define PPI_B		0x41
#define PPI_C		0x42
#define PPI_CTRL	0x43

