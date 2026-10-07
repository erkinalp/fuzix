/* For now */
extern void spi_select_port(uint8_t n);
#define spi_select_none()	spi_select_port(0)

#define spi_send	sd_spi_tx_byte
#define spi_recv	sd_spi_rx_byte
