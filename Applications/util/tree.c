#include <stdio.h>
#include <string.h>
#include <ftw.h>

static char *argn;

int iterator(const char *fp, const struct stat *sb, int type, struct FTW *ftw)
{
    const char *tp = fp + ftw->base;
    unsigned n = ftw->level;
    while(n > 1) {
        printf("|   ");
        n--;
    }
    if (n)
        printf("+---");
    printf("%s\n", tp);
    return 0;
}

void tree(const char *path)
{
    if (nftw(path, iterator, 2, FTW_PHYS) < 0)
            fprintf(stderr, "%s: failed to walk '%s'.\n", argn, path);
}

int main(int argc, char *argv[])
{
    argn = argv[0];
    if (argc == 1)
        tree(".");
    else  while(*++argv)
        tree(*argv);
    return 0;
}