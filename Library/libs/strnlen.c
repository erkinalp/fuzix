#include <string.h>

size_t strnlen(register const char *t, size_t n)
{
	register size_t ct = 0;
	while (*t++ && ct++ < n);
	return ct;
}
