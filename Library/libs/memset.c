#include <string.h>

void *memset(void *dest, int data, register size_t len)
{
	register char *p = dest;
	register char v = (char)data;

	while(len--)
		*p++ = v;
	return dest;
}
