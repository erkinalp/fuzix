/* Minimal FUZIX /init for Z8001 — spawn /bin/sh */

extern int open(const char *path, int flags);
extern int write(int fd, const void *buf, int count);
extern int execve(const char *path, char *argv[], char *envp[]);
extern int fork(void);
extern int waitpid(int pid, int *status, int options);
extern void _exit(int status);

static char ttydev[] = "/dev/tty1";

int main(void)
{
	int pid, status;
	static char sh_path[] = "/bin/sh";
	char *argv[2];
	char *envp[1];

	argv[0] = sh_path;
	argv[1] = 0;
	envp[0] = 0;

	open(ttydev, 2);	/* fd 0 */
	open(ttydev, 2);	/* fd 1 */
	open(ttydev, 2);	/* fd 2 */

	write(1, "[init]\n", 7);

	for (;;) {
		pid = fork();
		if (pid == 0) {
			execve("/bin/sh", argv, envp);
			write(1, "no sh\n", 6);
			_exit(1);
		}
		waitpid(pid, &status, 0);
	}
}
