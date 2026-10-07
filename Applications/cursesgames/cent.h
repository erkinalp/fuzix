#include <curses.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <fcntl.h>
#include <pwd.h>
#include <signal.h>
#include <termios.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ioctl.h>

#define CENT_DOC "/usr/lib/games/cent.txt"

/* User commands */
#define LEFT 'h'
#define RIGHT 'l'
#define UPWARD 'k'
#define DOWN 'j'
#define FIRE ' '
#define UPRIGHT 'u'
#define UPLEFT 'y'
#define DOWNRIGHT 'n'
#define DOWNLEFT 'b'
#define FASTLEFT 'H'
#define FASTRIGHT 'L'
#define PAUSEKEY '\t'

#define FREEMAN 12000
#define CENTLENGTH 20

/* Things appearing on the screen */
#define HEAD 'O'
#define BODY 'o'
#define UNSHOTMUSHROOM 'P'
#define ONCESHOTMUSHROOM 'p'
#define TWICESHOTMUSHROOM '.'
#define UNSHOTPOISON 'X'
#define ONCESHOTPOISON 'x'
#define TWICESHOTPOISON ','
#define YOU '!'
#define SHOT '*'
#define FLEA '@'

#define UNPOISONED 0
#define POISONED 1
#define WASPOISONED 2

typedef struct {
    int y;
    int x;
} COORD;

typedef struct pede {
    struct pede *next;		/* next pede in linked list of creatures */
    struct pede *prev;		/* previous pede in list */
    char type;			/* head or body */
    COORD pos;
    COORD oldpos;
    COORD speed;
    int overlap;		/* Did the piece overlap another last time? */
    int poisoned;		/* state of being poisoned */
} PEDE;

struct score;

#define COMPSPOTS(s1,s2) ((s1).y == (s2).y && (s1).x == (s2).x)
#define ADDPIECE(piece) mvaddch((piece)->pos.y,(piece)->pos.x,(piece)->type)
#define ERASE(y,x) mvaddch(y,x,mushw[y][x])
