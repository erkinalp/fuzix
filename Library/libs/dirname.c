#include <libgen.h>
#include <string.h>

/* Lots of funny cases for SuS compliance. We have to handle trailing / */

char *dirname(char *p)
{
    register char *s;
    register char *e = p + strlen(p) - 1;
    while(*e == '/') {
        if (e == p)
            return p;	/* dirname("/") is "/" */
        e--;
    }
    s = e;
    while(*s != '/')
        if (s == p) {
            /* Our entire path is of the form foo/ or foo */
            return ".";
        s--;
    }
    if (s == p) {
        /* Path is /foo/ or /foo */
        return "/";
    }
    /* Ok we do have a directory element */
    *s = 0;
    return p;
}
