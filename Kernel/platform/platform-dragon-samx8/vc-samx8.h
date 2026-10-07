#ifndef __VC_SAMX8_DOT_H__
#define __VC_SAMX8_DOT_H__

void vc_memset(unsigned char *, char, uint16_t);

void vc_write_char(unsigned char *, unsigned char);
char vc_read_char(unsigned char *);

void vc_scroll_up(void);
void vc_scroll_down(void);

#endif
