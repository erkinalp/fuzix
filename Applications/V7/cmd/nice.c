/* From UNIX V7 source code: see /COPYRIGHT or www.tuhs.org for details. */

/* nice */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

int main(int argc, char *argv[])
{
	int nicarg = 10;
	int exit_status = 127;

	if(argc > 1 && argv[1][0] == '-') {
		if (argv[1][1] == 'n') {
			argc++;
			argv++;
			nicarg = atoi(&argv[1][0]);
		} else
			nicarg = atoi(&argv[1][1]);
		argc--;
		argv++;
	}
	if(argc < 2) {
		fputs("usage: nice [ -n ] command\n", stderr);
		exit(125);
	}
	nice(nicarg);
	execvp(argv[1], &argv[1]);
	if (errno == ENOENT)
		exit_status = 126;
	perror(argv[1]);
	exit(exit_status);
}
