#include <string.h>

size_t strlcpy(char *dst, const char *src, size_t dstsize)
{
  /* dstsize 0 must write nothing, and the return is strlen(src)
     regardless (BSD semantics). A bare dstsize - 1 underflows to
     SIZE_MAX and the copy ploughs through all of memory - on a
     machine with no protection that is a system-wide corruption,
     found via cpp's quoted-include path handing this a zero bound. */
  size_t len = strlen(src);
  size_t cp;
  if (dstsize == 0)
    return len;
  cp = len >= dstsize ? dstsize - 1 : len;
  *(char *)mempcpy(dst, src, cp) = 0;
  return len;
}

size_t strlcat(char *dst, const char *src, size_t dstsize)
{
  size_t len = strlen(dst);
  /* No room at all (or a zero-size buffer: dstsize - 1 must not
     underflow): existing string fills the buffer */
  if (dstsize == 0 || len >= dstsize - 1)
    return len + strlen(src);
  return strlcpy(dst + len, src, dstsize - len);
}

