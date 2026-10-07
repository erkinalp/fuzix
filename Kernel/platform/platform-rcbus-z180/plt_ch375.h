extern void nap20(void);
extern void ch375_rblock(uint8_t *ptr);
extern void ch375_wblock(uint8_t *ptr);

#define CH375_DPORT	0xBE
#define CH375_SPORT	0xBF

#define ch375_rdata()	in(CH375_DPORT)
#define ch375_rstatus()	in(CH375_SPORT)

#define ch375_wdata(x)	out(CH375_DPORT, x)
#define ch375_wcmd(x)	out(CH375_SPORT, x)

