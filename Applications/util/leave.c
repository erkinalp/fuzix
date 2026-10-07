/*
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Copyright (c) 1980, 1988, 1993
 *	The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * Tidied and shrunk a bit: Alan Cox
 */

#include <ctype.h>
#include <err.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>

static void doalarm(unsigned int);
static void usage(void);


static void writes(const char *s)
{
	size_t l = strlen(s);
	if (write(1, s, l) != l)
		exit(EXIT_SUCCESS);
}

/*
 * leave [[+]hhmm]
 *
 * Reminds you when you have to leave.
 * Leave prompts for input and goes away if you hit return.
 * It nags you like a mother hen.
 */
int main(int argc, char **argv)
{
	unsigned int secs;
	int hours, minutes;
	char c, *cp = NULL;
	struct tm *t;
	time_t now;
	int plusnow, t_12_hour;
	char buf[50];

	if (setlocale(LC_TIME, "") == NULL)
		warn("setlocale");

	signal(SIGHUP, SIG_DFL);

	if (argc < 2) {
	        writes("When do you have to leave? ");
		cp = fgets(buf, sizeof(buf), stdin);
		if (cp == NULL || *cp == '\n')
			exit(EXIT_SUCCESS);
	} else if (argc > 2)
		usage();
	else
		cp = argv[1];

	if (*cp == '+') {
		plusnow = 1;
		++cp;
	} else
		plusnow = 0;

	for (hours = 0; (c = *cp) && c != '\n'; ++cp) {
		if (!isdigit(c))
			usage();
		hours = hours * 10 + (c - '0');
	}
	minutes = hours % 100;
	hours /= 100;

	if (minutes < 0 || minutes > 59)
		usage();
	if (plusnow)
		secs = hours * 60 * 60 + minutes * 60;
	else {
		time(&now);
		t = localtime(&now);

		if (hours > 23)
			usage();

		/* Convert tol to 12 hr time (0:00...11:59) */
		if (hours > 11)
			hours -= 12;

		/* Convert tm to 12 hr time (0:00...11:59) */
		if (t->tm_hour > 11)
			t_12_hour = t->tm_hour - 12;
		else
			t_12_hour = t->tm_hour;

		if (hours < t_12_hour ||
		   (hours == t_12_hour && minutes <= t->tm_min))
			/* Leave time is in the past so we add 12 hrs */
			hours += 12;

		secs = (hours - t_12_hour) * 60 * 60;
		secs += (minutes - t->tm_min) * 60;
		secs -= now % 60;	/* truncate (now + secs) to min */
	}
	doalarm(secs);
	exit(EXIT_SUCCESS);
}

static void doalarm(unsigned int secs)
{
	int bother;
	time_t daytime;
	char tb[80];
	int pid;

	if ((pid = fork())) {
		time(&daytime);
		daytime += secs;
//		strftime(tb, sizeof(tb), "%+", localtime(&daytime));
//		printf("Alarm set for %s. (pid %d)\n", tb, pid);
                printf("Alarm set for %s", ctime(&daytime));
		exit(EXIT_SUCCESS);
	}
	sleep((unsigned int)2);		/* let parent print set message */
	if (secs >= 2)
		secs -= 2;

	/*
	 * if write fails, we've lost the terminal through someone else
	 * causing a vhangup by logging in.
	 */
#define	FIVEMIN	(5 * 60)
	if (secs >= FIVEMIN) {
		sleep(secs - FIVEMIN);
		writes("\07\07You have to leave in 5 minutes.\n");
		secs = FIVEMIN;
	}

#define	ONEMIN	(60)
	if (secs >= ONEMIN) {
		sleep(secs - ONEMIN);
		writes("\07\07Just one more minute!\n");
	}

	for (bother = 10; bother--;) {
		sleep((unsigned int)ONEMIN);
                writes("\07\07Time to leave!\n");
	}
        writes("\07\07That was the last time I'll tell you.  Bye.\n");
	exit(EXIT_SUCCESS);
}

static void usage(void)
{
	fprintf(stderr, "usage: leave [[+]hhmm]\n");
	exit(EXIT_FAILURE);
}
