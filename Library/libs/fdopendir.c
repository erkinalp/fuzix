#include <unistd.h>
#include <alloc.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

DIR *fdopendir(int fd)
{
	register DIR *dir = calloc(1, sizeof(DIR));
	if (dir == NULL) {
		errno = ENOMEM;
		return NULL;
	}
	dir = fdopendir_r(dir, fd);
	if (dir == NULL)
		free(dir);
	return dir;
}
