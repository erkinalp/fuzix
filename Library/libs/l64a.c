#include <stdio.h>

static char buf[7];

static char str[] = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

char *l64a(long l)
{
  register char *p = buf;
  register uint32_t n = l;


  while(n && p < buf + 6) {
    *p++ = str[n & 63];
    n >>= 6;
  }
  *p = 0;
  return buf;
}

