/* A stab at a resolver

   NOTES:
   * only does recursive querries, doesn't to iterative.

   TODO:
   * needs to read rc file
   * retranslate textual IP address
   * should work with TCP too
   * fill out more of hostent struct

*/

#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <signal.h>
#include "netdb.h"

/* DNS packet header */
struct header{
    uint16_t id;       /* unique session ID */
    uint8_t  cntl;     /* bit fields - mostly request stuff */
    uint8_t  ret;      /* bit feilds - mostly return/stat stuff */
    uint16_t qdcount;  /* number of queries */
    uint16_t ancount;  /* number of answers */
    uint16_t nscount;  /* number of suggested name servers */
    uint16_t arcount;  /* number of suggested name server IP addresses */
};

/* Tail of Returned resource records (RR's) */
struct RRtail{
    uint16_t type;    /* which type of record, 1 = A, IP address */
    uint16_t class;   /* which network class, 1 = inet */
    uint32_t ttl;     /* time to live of records in secounds */
    uint16_t rdlen;   /* length of following data field, 4 for IP addresses */
};

#define MAXADDRS 4  /* max number of address stored in hostent struct */


/* Does nothing, used for timing out waiting for DNS packet(s) */
static void alarm_handler( int signum ){
    return;
}

static int fd;          /* file descriptor for inet socket */
static char buf[512];   /* packet buffer */


/* formulate and send a DNS query packet */
static int send_question( char *name ){
    struct header *p=( struct header *)buf;
    char *i = name;
    char *o = buf + sizeof(struct header);
    char *l = o++;

    memset( p, 0, sizeof(buf) );
    p->id = htons(42);     /* "random" query ID */
    p->cntl = 0x1;         /* request a recursive query */
    p->qdcount = htons(1); /* one question */
    /* fill out name string */

    while(1){
	if( ! *i )
	    break;
	if( *i == '.' ){
	    *l = o - l - 1 ;
	    i++;
	    l = o++;
	}
	else
	    *o++ = *i++;
    }
    *l = o - l - 1;
    *o++ = 0;
    /*
     * DNS fields are byte packed and may not be naturally aligned.
     * Avoid uint16_t structure accesses here as they fault on CPUs
     * such as ARM M0 when the encoded name has an odd length.
     */
    {
        uint16_t v = htons(1);
        /* type: A record */
        memcpy(o, &v, sizeof(v));
        o += sizeof(v);
        /* class: inet */
        memcpy(o, &v, sizeof(v));
        o += sizeof(v);
    }

    write( fd, buf, (int)(o - buf) );
    return 0;    
}



int h_errno;  /* Return error indicator */

static char addrs[MAXADDRS][4];   /* hostent static address table */

static char *list[MAXADDRS+1];    /* hostent static list of addresses */

static struct hostent host={      /* static returned hostent struct */
    NULL,
    NULL,
    AF_INET,
    4,
    list
};


/* Get a host by it's name */ 
struct hostent *gethostbyname( char *name ){
    struct sockaddr_in addr;
    static uint32_t av;
    int x;
    int tries = 5;
    int lno=0;
    char *ptr;
    char server[17];
    char *ws = " \f\n\r\t\v";

    /* Try to just translate passed stringified IP address */
    x = inet_pton( AF_INET, name, &av );
    if( x == 1 ){
	list[0] = (void *)&av;
	list[1] = NULL;
	return &host;
    }

    /* open up /etc/resolv.conf and read in
       fixme: handles only small config files < 512 bytes
       fixme: if we have other gethostby-whatever functions, this should
       be factored out as it's own static function */
    fd = open( "/etc/resolv.conf", O_RDONLY );
    if( fd < 0 ){
	return NULL;
    }
    x = read( fd, buf, 511 );
    if( x < 1 ){
	close( fd );
	return NULL;
    }
    buf[x]=0;
    ptr = strtok( buf, ws );
    while( ptr ){
	if( ! strcmp( ptr, "nameserver" ) ){
	    ptr=strtok( NULL, ws );
	    if( ptr == NULL ){
		return NULL;
	    }
	    strcpy( server, ptr );
	}
	ptr = strtok( NULL, ws );
    }


    fd = socket( AF_INET, SOCK_DGRAM, 0);
    if( fd < 0 ){
	return NULL;
    }

    addr.sin_family = AF_INET;
    addr.sin_port = htons( 53 );

    inet_pton( AF_INET, server, &addr.sin_addr.s_addr );

    if( connect( fd, (struct sockaddr *)&addr, sizeof(addr) ) < 0 )
	goto error;

    for( ; tries ; tries-- ){
	send_question( name );
	signal( SIGALRM, alarm_handler );
	alarm(2);
	x = read( fd, buf, 512 );
	if( x < 0 )
	    continue;
	goto process;
    }
    h_errno = HOST_NOT_FOUND;
    goto error;

 process:
    /* process packet */
    alarm(0);
    {
	struct header *h = (struct header *)buf;
        int i;
        uint16_t qdcount;
        uint16_t ancount;
        uint16_t rdlen;
        uint16_t type;
        uint16_t class;

        /* Convert the wire values once and use ordinary host-order values */
        qdcount = ntohs(h->qdcount);
        ancount = ntohs(h->ancount);

        if( ntohs(h->id) != 42 )  /* correct session ID ? */
	    goto error;

	if( ! (h->cntl & 0x80) )  /* is an answer packet? */
	    goto error;

	if( ! (h->ret & 0x80) )  /* is a recursive answer? */
	    goto error;

        if( ! ancount ) /* is there any answers? */
	    goto error;

	/* skip over our question(s) */
	ptr = buf + sizeof( struct header );
        for( i = 0; i < qdcount && i < 4; i++ ){
	    while(1){
		if( *ptr == 0 ){
		    ptr++;
		    break;
		}
		if( (*ptr & 0xc0) == 0xc0 ){
		    ptr += 2;
		    break;
		}
		ptr += *ptr + 1;
	    }
	    ptr +=4;
	}
	/* cap answers at MAXADDRS */
	if( ancount > MAXADDRS )
	    ancount = MAXADDRS;
	/* Iterate over answers */
        for( i = 0; i < ancount; i++ ){
	    /* parse off name */
	    while(1){
		if( *ptr == 0 ){
		    ptr++;
		    break;
		}
		if( (*ptr & 0xc0) == 0xc0 ){
		    ptr += 2;
		    break;
		}
		ptr += *ptr + 1;
	    }
	    /* point to rest of RR structure */
             /* DNS resource records are byte packed and may not be naturally
             * aligned. Do not access them through a C structure: unaligned
             * accesses fault on CPUs such as ARM M0 and structure padding may
             * make sizeof(struct RRtail) differ from the 10-byte wire format.
             */
            memcpy(&type, ptr, sizeof(type));
            ptr += sizeof(type);
            memcpy(&class, ptr, sizeof(class));
            ptr += sizeof(class);
            /* skip TTL */
            ptr += 4;
            memcpy(&rdlen, ptr, sizeof(rdlen));
            ptr += sizeof(rdlen);
            type = ntohs(type);
            class = ntohs(class);
            rdlen = ntohs(rdlen);
            if (type == 1 && class == 1 && rdlen == 4) {
                memcpy(addrs[lno], ptr, 4);
                list[lno] = &addrs[lno][0];
                lno++;
            }
            ptr += rdlen;
	}
	list[lno] = NULL;
    }
    close(fd);
    return &host;
 error:
    close(fd);
    return NULL;
}

