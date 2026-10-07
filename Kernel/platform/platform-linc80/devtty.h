#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__

#define SIO0_BASE 0x00
#define SIOA_D	0x00
#define SIOB_D	0x01
#define SIOA_C	0x02
#define SIOB_C	0x03

extern void sio2_otir(uint8_t port);

void tty_putc(uint_fast8_t minor, uint_fast8_t c);

extern void sioa_txqueue(uint8_t c);
extern void sioa_flow_control_on(void);
extern void sioa_flow_control_off(void);
extern uint16_t sioa_rx_get(void);
extern uint8_t sioa_error_get(void);

extern uint8_t sio_dropdcd[2];
extern uint8_t sio_flow[2];
extern uint8_t sio_rxl[2];
extern uint8_t sio_state[2];
extern uint8_t sio_txl[2];
extern uint8_t sio_wr5[2];

extern void siob_txqueue(uint8_t c);
extern void siob_flow_control_on(void);
extern void siob_flow_control_off(void);
extern uint16_t siob_rx_get(void);
extern uint8_t siob_error_get(void);

extern void tty_drain_sio(void);


#endif
