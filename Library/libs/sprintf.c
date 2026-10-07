/* printf.c
 *    Dale Schumacher			      399 Beacon Ave.
 *    (alias: Dalnefre')		      St. Paul, MN  55104
 *    dal@syntel.UUCP			      United States of America
 *
 * Altered to use stdarg, made the core function vfprintf.
 * Hooked into the stdio package using 'inside information'
 * Altered sizeof() assumptions, now assumes all integers except chars
 * will be either
 *  sizeof(xxx) == sizeof(long) or sizeof(xxx) == sizeof(short)
 *
 * -RDB
 *
 * Added snprintf Alan Cox
 * TODO: split this into multiple files a bit
 */

#include <stdarg.h>
#include "printf.h"

int sprintf(char *sp, const char *fmt, ...)
{
	static FILE string[1] = {
	{0, 0, (unsigned char *) -1,
	 0, (unsigned char *) -1, -1,
	 _IOFBF | __MODE_WRITE}
};
	va_list ptr;
	int rv;
	unsigned char *p = string->bufpos;

	va_start(ptr, fmt);
	string->bufpos = (unsigned char *) sp;
	rv = _vfnprintf(string, ~0, fmt, ptr);
	va_end(ptr);
	*(string->bufpos) = 0;

	string->bufpos = p;
	return rv;
}

int snprintf(char *sp, size_t size, const char *fmt, ...)
{
	static FILE string[1] = {
	{0, 0, (unsigned char *) -1,
	 0, (unsigned char *) -1, -1,
	 _IOFBF | __MODE_WRITE}
};
	va_list ptr;
	int rv;
	unsigned char *p = string->bufpos;
	register size_t n = size;

	if (n)
		n--;

	va_start(ptr, fmt);
	string->bufpos = (unsigned char *) sp;
	rv = _vfnprintf(string, n, fmt, ptr);
	va_end(ptr);
	if (size)
		*(string->bufpos) = 0;

	string->bufpos = p;
	return rv;
}

int vsnprintf(char *sp, size_t size, const char *fmt, va_list ptr)
{
	static FILE string[1] = {
	{0, 0, (unsigned char *) -1,
	 0, (unsigned char *) -1, -1,
	 _IOFBF | __MODE_WRITE}
};
	int rv;
	unsigned char *p = string->bufpos;
	register size_t n = size;

	if (n)
		n--;

	string->bufpos = (unsigned char *) sp;
	rv = _vfnprintf(string, n, fmt, ptr);
	if (size)
		*(string->bufpos) = 0;

	string->bufpos = p;
	return rv;
}

int vsprintf(char *sp, const char *fmt, va_list ptr)
{
	static FILE string[1] = {
	{0, 0, (unsigned char *) -1,
	 0, (unsigned char *) -1, -1,
	 _IOFBF | __MODE_WRITE}
};
	int rv;
	unsigned char *p = string->bufpos;

	string->bufpos = (unsigned char *) sp;
	rv = _vfnprintf(string, ~0, fmt, ptr);
	*(string->bufpos) = 0;

	string->bufpos = p;
	return rv;
}
