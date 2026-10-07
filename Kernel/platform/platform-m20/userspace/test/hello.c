/* Simple test program for fork+exec */

extern int write(int fd, const void *buf, int count);
extern void _exit(int status);

static char msg[] = "hello from exec!\n";

int main(void)
{
	write(1, msg, 17);
	_exit(0);
	return 0;
}
