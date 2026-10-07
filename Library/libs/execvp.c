/* execvp.c
 *
 * function(s)
 *	  execvp - load and execute a program
 */

#include <unistd.h>
#include <stdio.h>
#include <paths.h>

int execvp(const char *pathP, char *const argv[])
{
	char name[PATHLEN + 1];
	return execve(_findPath(name, pathP), argv, (void *)environ);
}
