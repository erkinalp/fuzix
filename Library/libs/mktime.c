/*
 *	A really stupid mktime
 */

#include <time.h>

static int try_mktime(time_t t, register struct tm *want, register struct tm *tm)
{
    localtime_r(&t, tm);
    if (tm->tm_year < want->tm_year)
        return -1;
    if (tm->tm_year > want->tm_year)
        return 1;
    if (tm->tm_mon < want->tm_mon)
        return -1;
    if (tm->tm_mon > want->tm_mon)
        return 1;
    if (tm->tm_mday < want->tm_mday)
        return -1;
    if (tm->tm_mday > want->tm_mday)
        return 1;
    if (tm->tm_hour < want->tm_hour)
        return -1;
    if (tm->tm_hour > want->tm_hour)
        return 1;
    if (tm->tm_min < want->tm_min)
        return -1;
    if (tm->tm_min > want->tm_min)
        return 1;
    if (tm->tm_sec < want->tm_sec)
        return -1;
    if (tm->tm_sec > want->tm_sec)
        return 1;
    return 0;
}

time_t mktime(struct tm *want)
{
    int d;
    struct tm tm;
    time_t t = 0x80000000UL;	/* FIXME: 64bit time_t will need a saner
                                   approach */
    time_t diff = t / 2;

    /* Shouldn't need && diff but at least we terminate whilst debugging */
    while((d = try_mktime(t, want, &tm)) != 0 && diff) {
        if (d < 0)
            t += diff;
        else
            t -= diff;
        diff /= 2;
    }
    return t;
}

#ifdef TEST
#include <stdio.h>
int main(int argc, char *argv[])
{
    time_t t = time(NULL);
    struct tm *tp = localtime(&t);
    printf("%lu %lu\n", (unsigned long)mktime(tp), (unsigned long)t);
    return 0;
}
#endif
