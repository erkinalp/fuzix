#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

char *mkdtemps(char *s, int slen)
{
  __ktime_t t;
  char *p = s + strlen(s) - slen - 6;
  register uint16_t value;
  const char *n;
  int err;

  if (p < s)
    goto bad;
  if (memcmp(p, "XXXXXX", 6))
    goto bad;
  _time(&t, 0);
  value = (getuid() << 8) + getpid() + (uint16_t)t.low;
  do {
    value += 7919;	/* Any old prime ought to do */
    n = _itoa(value);
    memcpy(p, "000000", 6);
    memcpy(p + 6 - strlen(n), n, strlen(n));
    err = mkdir(s, 0700);
  }
  while(err == -1 && errno == EEXIST);
  if (err)
    return NULL;
  return s;
bad:
  errno = EINVAL;
  return NULL;
}

char *mkdtemp(char *s)
{
  return mkdtemps(s, 0);
}
