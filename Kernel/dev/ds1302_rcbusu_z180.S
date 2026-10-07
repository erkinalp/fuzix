	.code

#define PIN_CE          0xEF10
#define PIN_DATA_HIZ    0xDF20
#define PIN_CLK         0xBF40
#define PIN_DATA_OUT    0x7F80
#define PIN_DATA_IN     0x01
#define PIN_OTHER	0x0C	; Force SPI selects high during RTC
				; so we don't drive both at once in error


#include "ds1302_commonu.s"
