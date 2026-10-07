#include <unistd.h>
#include <alloc.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>

DIR *fdopendir_r(register DIR *dir, int fd)
{
	struct stat statbuf;

	if (fstat(fd, &statbuf) != 0)
		return NULL;

	if ((statbuf.st_mode & S_IFDIR) == 0) {
		errno = ENOTDIR;
		return NULL;
	}
	dir->dd_fd = fd;
	dir->dd_loc = 0;
	dir->_priv.next = 0;
	dir->_priv.last = 0;
	return dir;
}
