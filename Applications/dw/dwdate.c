/* A program to get the time from drivewire.  Displays it or sets the
   system clock from it.  Must be super user
*/


#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <errno.h>
#include <sys/drivewire.h>


char *devname="/dev/dw0";

static const uint16_t mktime_moffset[12]= { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };

int silent = 0; /* silent I/O failure flag */

static void printe( char *s ){
    write(2, s, strlen(s) );
    write(2, "\n", 1 );
}

static int get_time( uint8_t *tbuf )
{
    int fd;
    int ret;
    struct dw_trans d;

    fd = open( devname, O_RDONLY );
    if( fd < 1){
	perror( "drivewire device open");
	exit(1);
    }

    tbuf[0]=0x23;
    d.sbuf = tbuf;
    d.sbufz = 1;
    d.rbuf = tbuf;
    d.rbufz = 6;

    ret = ioctl( fd, DRIVEWIREC_TRANS, &d );
    if (ret)
        if (errno != EIO || !silent)
            perror("drivewire");
    close( fd );
    return ret;
}


int main( int argc, char *argv[] ){
    register struct tm *tm;
    time_t t;
    int i,x;
    unsigned char buf[6];
    int setflg = 0;     /* set system time flag */
    int disflg = 0;     /* display retrieved time flag */
    int parbrk = 0;     /* parse break flag */

    /* scan args */
    for( x = 1; x < argc; x++ ){
	if( argv[x][0] != '-' ){
	    printe( "bad arg" );
	    exit(1);
	}
	for( i = 1; argv[x][i]; i++ ){
	    switch( argv[x][i] ){
	    case 's':
		setflg = 1;
		break;
	    case 'd':
		disflg = 1;
		break;
	    case 'q':
		silent = 1;
		break;
	    case 'x':
		devname = argv[++x];
		if( ! devname ){
		    printe("bad device name");
		    exit(1);
		}
		parbrk = 1;
		break;
	    default:
		printe("bad option" );
		exit(1);
	    }
	    if( parbrk ){
		parbrk = 0;
		break;
	    }
	}
    }

    /* get the static struct tm */
    time(&t);
    tm = localtime(&t);

    /* fetch time from DW */
    if (get_time(buf))
	exit(1);

    /* populate the struct tm */
    tm->tm_sec = buf[5];
    tm->tm_min = buf[4];
    tm->tm_hour = buf[3];
    tm->tm_mday = buf[2];
    tm->tm_mon = buf[1] - 1;
    tm->tm_year = buf[0];
    if (tm->tm_year < 70)
	    tm->tm_year += 100;

    /* convert to time_t */
    t = mktime(tm);

    if( disflg || !setflg )
	fputs(ctime(&t),stdout);

    if( setflg ){
	/* This is a sleezy cast */
	x=stime(&t);
	if( x ){
	    perror( "stime" );
	    exit(1);
	}
    }

    exit(0);
}
