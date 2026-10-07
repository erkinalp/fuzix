

void devsd_read( void *addr );
void devsd_write( void *addr );
int devsd_flush( void );
uint8_t devsd_transfer_sector(void);
bool devsd_exist(void);
void devsd_init(void);
