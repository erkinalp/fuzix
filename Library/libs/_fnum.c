/*
 * floating point output. From ELKS but renamed to avoid symbol clashes with
 * user namespace
 *
 * Added 'g' output format
 * Apr 2022 Greg Haerr
 */
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>

void _fnum(double val, int style, int preci, char *buf)
{
   int decpt, negative, diddecpt = 0;
   char * cvt;

   style = tolower(style);
   if (preci < 0) preci = 6;

   if (style == 'e')
       cvt = ecvt(val, preci, &decpt, &negative);	/* preci = ndigits */
   else cvt = fcvt(val, preci, &decpt, &negative);
   if(negative)
      *buf++ = '-';

   if (decpt<=0) {
      *buf++ = '0';
      *buf++ = '.';
      diddecpt = 1;
      while(decpt<0) {
         *buf++ = '0';
         decpt++;
      }
   }

   while(*cvt) {
      *buf++ = *cvt++;
      if (decpt == 1) {
         *buf++ = '.';
         diddecpt = 1;
      }
      decpt--;
   }

   while(decpt > 0) {
      *buf++ = '0';
      decpt--;
   }
   *buf = 0;
   if (style == 'g' && diddecpt) {
      for (;;) {
         int c = *--buf;
         if (c == '0' || c == '.')
            *buf = 0;
         if (c != '0') break;
      }
   }

}
