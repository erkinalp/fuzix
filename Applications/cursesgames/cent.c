/* Centipede
   Copyright 1987 by Nathan Glasser
   Do not redistribute this source code without including this
   copyright notice.
*/


#include "cent.h"

PEDE *centipede;		/* head of the list */
PEDE *lastpede;			/* last pede in list */
int numpedes;
char mushw[24][57];		/* Array to store mushrooms */
struct termios origterm;	/* the terminal before */
volatile int inter = 0;
int gamestarted = 0;
int dead = 0;
COORD guy = { 22, 28 };		/* your coordinates */

COORD shot;			/* the shot's coordinates */
int fired = 0;			/* a shot has been fired */
long score = 0;
int board = 1;
int extramen = 3;
long nextman = FREEMAN;
int finished;			/* time since board ended */
int breeding;			/* are they breeding */
int breedtime = 300;		/* moves between breeds */
int moves = 0;
int fleahere = 0;		/* a flea is on the screen */
COORD flea;
int fleashot;			/* was it shot once */
int fleafreq;			/* a figure which helps determine the
				   frequency of fleas on a board */
int nummushrooms;		/* number of mushrooms in player area */
char lscorpion[] = "\\`oo'--/";
char rscorpion[] = "\\--\\`oo'";
char *scorppic;
int scorphere = 0;		/* is there a scorpion on the screen */
int scorpthisboard;
int scorpvel;
COORD scorp;
char *spiderpic[] = {
    "/\\  /\\",
    "/\\oo/\\"
};

int spiderhere = 0;
COORD spider;
COORD spidervel;
int spiderdir;
int spidcount;

static int rnd(register int n)
{
    /* Number between 0 and n-1 I think CHECK FIXME */
    return (rand() % n);
}

static void redrawscr(void)
{
    touchwin(stdscr);
    refresh();
}

static void printpic(char **pic, int len, int y, int x)
{
    register int i;
    for (i = 0; i < len; i++)
	mvaddstr(i + y, x, pic[i]);
}

static void drawpic(char **pic, int len, int wid, int y, int x)
{
    register int yy, xx, start, end, pos;

    start = (x < 1) ? 1 - x : 0;
    end = (x > 56 - wid) ? 56 - x : wid;
    for (yy = 0; yy < len; yy++)
	for (pos = start, xx = (x < 1) ? 1 : x; pos < end; pos++, xx++)
	    if (pic[yy][pos] != ' ')
		mvaddch(y + yy, xx, pic[yy][pos]);
}

static void erasepic(int len, int wid, int y, int x)
{
    register int xx, yy, twid, newx;

    twid = ((x > 56 - wid) ? 56 - x : wid) - ((x < 1) ? 1 - x : 0);
    newx = (x < 1) ? 1 : x;
    for (yy = 0; yy < len; yy++)
	for (xx = newx; xx < newx + twid; xx++)
	    ERASE(y + yy, xx);
}

static void displaymen(void)
{
    static char men[15];
    register int i;

    for (i = 0; i < 6 && i < extramen; i++)
	men[i] = YOU;
    if (extramen > 6)
	sprintf(men + 6, " (%u)", extramen);
    else
	men[i] = 0;
    move(23, 60);
    clrtoeol();
    addstr(men);
}

static void addscore(int n)
{
    score += n;
    mvprintw(2, 67, "%lu", score);
    if (score >= nextman) {
	mvprintw(21, 67, "%lu", nextman += FREEMAN);
	extramen++;
	displaymen();
	mvaddstr(12, 66, "You've won");
	mvaddstr(13, 65, "a free man!!");
	refresh();
	sleep(2);
	move(12, 66);
	clrtoeol();
	move(13, 65);
	clrtoeol();
    }
}

static void addshroom(int y, int x)
{
    if (y == 22) {
	mvaddstr(15, 60, "Mushroom on last row");
	return;
    }
    mvaddch(y, x, UNSHOTMUSHROOM);
    mushw[y][x] = UNSHOTMUSHROOM;
    if (y >= 18)
	nummushrooms++;
}

static void instructions(void)
{
    char buf[80];
    FILE *fp;

    printf("Welcome to Centipede version 1.8\n");

    fp = fopen(CENT_DOC, "r");
    if (fp) {
	printf("Would you like instructions(y/n)?");
	fflush(stdout);
	if (fgets(buf, 79, stdin) == NULL)
	    exit(0);
	if (*buf == 'y' || *buf == 'Y') {
	    while (fgets(buf, 79, fp))
		fputs(buf, stdout);
	}
	fclose(fp);
    }
    printf("[Hit return to start the game]");
    fflush(stdout);
    fgets(buf, 79, stdin);
}

static PEDE *getpede(int y, int x)
{
    register PEDE *pede;

    for (pede = centipede; pede != NULL; pede = pede->next)
	if (pede->pos.y == y && pede->pos.x == x)
	    return (pede);
    return (NULL);
}


static void shootpede(void)
{
    register PEDE *piece;

    piece = getpede(shot.y, shot.x);
    if (piece->type == HEAD)
	addscore(100);
    else
	addscore(10);
    if (piece != centipede)
	piece->prev->next = piece->next;
    else if ((centipede = centipede->next) == NULL) {
	finished = 1;
	breeding = 0;
	move(1, 67);
	clrtoeol();
	printw("%u", ++board);
    }
    if (piece->next != NULL) {
	PEDE *pp = piece->next;

	pp->type = HEAD;
	pp->prev = piece->prev;
	if (piece->poisoned)
	    do
		pp->poisoned = WASPOISONED;
	    while ((pp = pp->next) != NULL && pp->type != HEAD);
    } else
	lastpede = piece->prev;
    addshroom(shot.y, shot.x);
    free(piece);
    numpedes--;
}

static void startflea(void)
{
    fleahere = 1;
    fleashot = 0;
    flea.y = 0;
    flea.x = rnd(55) + 1;
    mvaddch(flea.y, flea.x, FLEA);
}

static void shootflea(void)
{
    if (!fleashot) {
	fleashot = 1;
	mvaddch(flea.y, flea.x, FLEA);
	return;
    }
    fleahere = 0;
    ERASE(flea.y, flea.x);
    addscore(200);
    startflea();
}

static void shootspider(void)
{
    spiderhere = 0;
    erasepic(2, 6, spider.y, spider.x);
    spidcount = 0;
    if (guy.y - spider.y == 2)
	addscore(900);
    else if (guy.y - spider.y < 4)
	addscore(600);
    else
	addscore(300);
}


static void checkhit(void)
{
    register char thing;

    if ((thing = mvinch(shot.y, shot.x)) != ' ' && inch() != SHOT && inch() != YOU) {	/* he hit something */
	fired = 0;
	mvaddch(shot.y, shot.x, SHOT);
	refresh();
	switch (thing) {
	case UNSHOTMUSHROOM:
	    mvaddch(shot.y, shot.x, ONCESHOTMUSHROOM);
	    mushw[shot.y][shot.x] = ONCESHOTMUSHROOM;
	    break;
	case ONCESHOTMUSHROOM:
	    mvaddch(shot.y, shot.x, TWICESHOTMUSHROOM);
	    mushw[shot.y][shot.x] = TWICESHOTMUSHROOM;
	    break;
	case TWICESHOTMUSHROOM:
	case TWICESHOTPOISON:
	    mvaddch(shot.y, shot.x, ' ');
	    mushw[shot.y][shot.x] = ' ';
	    addscore(1);
	    if (shot.y >= 18)
		nummushrooms--;
	    break;
	case UNSHOTPOISON:
	    mvaddch(shot.y, shot.x, ONCESHOTPOISON);
	    mushw[shot.y][shot.x] = ONCESHOTPOISON;
	    break;
	case ONCESHOTPOISON:
	    mvaddch(shot.y, shot.x, TWICESHOTPOISON);
	    mushw[shot.y][shot.x] = TWICESHOTPOISON;
	    break;
	default:
	    if (getpede(shot.y, shot.x) != NULL)
		shootpede();
	    else if (fleahere && COMPSPOTS(shot, flea))
		shootflea();
	    else if (spiderhere &&
		     (shot.y == spider.y || shot.y == spider.y + 1)
		     && spider.x <= shot.x && shot.x <= spider.x + 5)
		shootspider();
	    else if (scorphere && shot.y == scorp.y &&
		     scorp.x <= shot.x && shot.x <= scorp.x + 6) {
		scorphere = 0;
		erasepic(1, 7, scorp.y, scorp.x);
		addscore(1000);
	    } else {
		mvprintw(15, 60, "Unknown char: %c", thing);
		ERASE(shot.y, shot.x);
		refresh();
	    }
	}
    }
}

static void catchint(int sig)
{
    signal(SIGINT, SIG_IGN);
    inter = 1;
}

static void waitboard(void)
{
    int ch;

    signal(SIGINT, SIG_IGN);
    mvaddstr(12, 60, "Press return");
    mvaddstr(13, 60, "when ready");
    refresh();
    nocbreak();
    cbreak();
    while ((ch = getch()) != '\r' && ch != '\n' && ch != ERR) {
	if (ch == '\014' || ch == 'r')
	    redrawscr();
    }
    halfdelay(1);
    move(12, 60);
    clrtoeol();
    move(13, 60);
    clrtoeol();
    move(15, 60);
    clrtoeol();
    signal(SIGINT, catchint);
}

/* We could use gettimeofday() I guess and should if portable - Alan */

#if defined(__linux__)
/* Cross testing hack */
static unsigned fuzix_clock(void)
{
    static unsigned n;
    return n++;
}
#else

static unsigned fuzix_clock(void)
{
    __ktime_t t;
    _time(&t, 0);
    return t.low;
}
#endif

static void move_guy(void)
{
    register int y, x, changed = 0;
    int repeat = 0;
    int ch;
    unsigned t = fuzix_clock();

    while (t == fuzix_clock() || repeat) {
	if (repeat)
	    repeat--;
	else {
	    ch = getch();
	    if (ch == ERR)
		break;
	}
	if (dead)
	    continue;
	y = guy.y;
	x = guy.x;
	switch (ch) {
	case '\014':		/* KDW */
	    redrawscr();
	    refresh();
	    break;
	case '4':
	case LEFT:
	    x--;
	    break;
	case '6':
	case RIGHT:
	    x++;
	    break;
	case '8':
	case UPWARD:
	    y--;
	    break;
	case '2':
	case DOWN:
	    y++;
	    break;
	case '9':
	case UPRIGHT:
	    x++;
	    y--;
	    break;
	case '7':
	case UPLEFT:
	    x--;
	    y--;
	    break;
	case '3':
	case DOWNRIGHT:
	    x++;
	    y++;
	    break;
	case '1':
	case DOWNLEFT:
	    x--;
	    y++;
	    break;
	case '\n':
	case '\r':
	case FIRE:
	    if (!fired) {
		fired = 1;
		shot.y = guy.y - 1;
		shot.x = guy.x;
		checkhit();
		changed = 1;
		if (fired)
		    mvaddch(shot.y, shot.x, SHOT);
	    }
	    continue;
	case PAUSEKEY:
	    waitboard();
	    continue;
	case FASTLEFT:
	    repeat = 8;
	    ch = LEFT;
	    continue;
	case FASTRIGHT:
	    repeat = 8;
	    ch = RIGHT;
	    continue;
	default:
	    continue;
	}

	if (ch == UPRIGHT || ch == UPLEFT || ch == DOWNRIGHT
	    || ch == DOWNLEFT) {
	    if (y < 18)
		y = 18;
	    else if (y > 22)
		y = 22;
	    if (x < 1)
		x = 1;
	    else if (x > 55)
		x = 55;
	    if (y == guy.y && x == guy.x)
		continue;
	}
	if (x >= 1 && x <= 55 && y >= 18 && y <= 22) {
	    if (getpede(y, x) != NULL
		|| (fleahere && y == flea.y && x == flea.x)
		|| (spiderhere && (y == spider.y || y == spider.y + 1)
		    && spider.x <= x && x <= spider.x + 5)) {
		dead = 1;
		mvaddch(y, x, YOU);
		ERASE(guy.y, guy.x);
		guy.y = y;
		guy.x = x;
		changed = 1;
	    } else if (mvinch(y, x) == ' ') {
		addch(YOU);
		ERASE(guy.y, guy.x);
		guy.y = y;
		guy.x = x;
		changed = 1;
	    }
	}
    }
    if (changed)
	refresh();
}

static void endgame(void)
{
    int ch;
    signal(SIGINT, SIG_IGN);
    mvaddstr(22, 60, "[Press return");
    mvaddstr(23, 60, " to continue]");
    refresh();
    nocbreak();
    nl();
    while ((ch = getch()) != '\n' && ch != ERR);
    echo();
    endwin();
    printf("\n\n");
    exit(0);
}

static void quit(void)
{
    int ch;

    mvaddstr(12, 60, "Really quit?");
    refresh();
    nocbreak();
    cbreak();
    ch = getch();
    move(12, 60);
    clrtoeol();
    refresh();
    if (ch == 'y' || ch == 'Y' || ch == ERR)
	endgame();
    inter = 0;
    halfdelay(1);
}

static void make_screen(void)
{
    register int i, y, x;

    clear();
    for (y = 0; y <= 22; y++)
	for (x = 1; x <= 55; x++)
	    mushw[y][x] = ' ';
    for (i = 0; i <= 22; i++) {
	mvaddch(i, 0, '|');
	mushw[i][0] = '|';
	mvaddch(i, 56, '|');
	mushw[i][56] = '|';
    }
    mvaddch(17, 0, '-');
    mushw[17][0] = '-';
    mvaddch(17, 56, '-');
    mushw[17][56] = '-';
    move(23, 0);
    for (i = 0; i <= 56; i++) {
	addch('-');
	mushw[23][i] = '-';
    }
    nummushrooms = 0;
    for (i = 45 + rnd(15); i; i--) {
	do {
	    y = rnd(22);	/* not on bottom row */
	    x = rnd(55) + 1;
	}
	while (mvinch(y, x) != ' ');
	addshroom(y, x);
    }
    mvprintw(1, 60, "Board: %d", board);
    mvprintw(2, 60, "Score: %ld", score);
    mvaddstr(20, 60, "Next free man:");
    mvprintw(21, 67, "%lu", nextman);
    displaymen();
    waitboard();
    extramen--;
    displaymen();
}

static void make_cent(int num_free)
{
    register int i;
    int vel = 2 * rnd(2) - 1;
    register PEDE **piece = &centipede, *prev = NULL;

    for (i = 0; i < CENTLENGTH; i++) {
	*piece = (PEDE *) malloc(sizeof(PEDE));
	if (*piece == NULL) {
	    fputs("Out of memory.\n", stderr);
	    exit(1);
	}
	(*piece)->prev = prev;
	(*piece)->pos.y = 0;
	(*piece)->speed.y = 1;
	(*piece)->overlap = 0;
	(*piece)->poisoned = 0;
	(*piece)->speed.x =
	    (i < CENTLENGTH - num_free) ? vel : 2 * rnd(2) - 1;
	(*piece)->type = (i == 0
			  || i >= CENTLENGTH - num_free) ? HEAD : BODY;
	prev = *piece;
	piece = &(*piece)->next;
    }
    lastpede = prev;
    *piece = NULL;
}

static void put_pede(void)
{
    register PEDE *piece = centipede;
    register int x;

    finished = breeding = scorpthisboard = 0;
    numpedes = CENTLENGTH;
    mvaddch(guy.y, guy.x, YOU);
    piece->pos.x = 22 + rnd(12);
    ADDPIECE(piece);
    while ((piece = piece->next) != NULL) {
	if (piece->type == BODY)
	    piece->pos.x = piece->prev->pos.x - piece->prev->speed.x;
	else {
	    while (mvinch(0, x = rnd(55) + 1) == HEAD || inch() == BODY);
	    piece->pos.x = x;
	}
	ADDPIECE(piece);
    }
}

static void contdeath(void)
{
    register PEDE *piece, *next;
    register int y, x;

    if (fleahere) {		/* erase flea */
	ERASE(flea.y, flea.x);
	fleahere = 0;
    }
    if (fired) {		/* erase shot */
	ERASE(shot.y, shot.x);
	fired = 0;
    }
    if (scorphere) {		/* erase scorpion */
	erasepic(1, 7, scorp.y, scorp.x);
	scorphere = 0;
    }
    spidcount = 0;
    if (spiderhere) {		/* erase spider */
	erasepic(2, 6, spider.y, spider.x);
	spiderhere = 0;
    }
    for (piece = centipede; piece != NULL; piece = next) {
	next = piece->next;
	ERASE(piece->pos.y, piece->pos.x);
	free(piece);
    }
    for (y = guy.y - 1; y <= guy.y + 1; y++)
	for (x = guy.x - 1; x <= guy.x + 1; x++)
	    ERASE(y, x);
    guy.y = 22;
    guy.x = 28;
    displaymen();
    dead = 0;
}

static void countmushrooms(void)
{
    register int y, x, flag;
    char cu, cd, cl, cr, cm;	/* Characters on screen being overwritten */

    for (x = 1; x <= 55; x++)
	for (y = 22; y >= 0; y--)
	    if (mushw[y][x] != ' ' && mushw[y][x] != UNSHOTMUSHROOM) {
		flag = mushw[y][x] != (cm = mvinch(y, x));
		mushw[y][x] = UNSHOTMUSHROOM;
		if (y > 0) {
		    cu = mvinch(y - 1, x);
		    mvaddch(y - 1, x, '|');
		}
		cd = mvinch(y + 1, x);
		mvaddch(y + 1, x, '|');
		cl = mvinch(y, x - 1);
		mvaddch(y, x - 1, '-');
		cr = mvinch(y, x + 1);
		mvaddch(y, x + 1, '-');
		refresh();
		if (y > 0)
		    mvaddch(y - 1, x, cu);
		mvaddch(y + 1, x, cd);
		mvaddch(y, x - 1, cl);
		mvaddch(y, x + 1, cr);
		mvaddch(y, x, ((flag) ? cm : UNSHOTMUSHROOM));
		addscore(5);
		refresh();
	    }
}

static void death(void)
{
    static char *ouch[] = {
	"\\|/",
	"-*-",
	"/|\\"
    };

    mvaddch(guy.y, guy.x, '*');
    refresh();
    mvaddstr(guy.y, guy.x - 1, "-*-");
    refresh();
    printpic(ouch, 3, guy.y - 1, guy.x - 1);
    refresh();
    countmushrooms();
    if (!extramen--)
	endgame();
    waitboard();
    contdeath();
}

static void dobreed(void)
{				/* bring on the reinforcements! */
    if (++moves >= breedtime && rnd(10) < 9) {
	if (breedtime > 125)
	    breedtime -= 10;
	else if (breedtime > 55)
	    breedtime -= 5;
	if (breedtime > 25)
	    breedtime--;
	moves = 0;
	lastpede->next = (PEDE *) malloc(sizeof(PEDE));
	lastpede->next->prev = lastpede;
	lastpede = lastpede->next;
	lastpede->next = NULL;
	lastpede->overlap = 0;
	lastpede->poisoned = UNPOISONED;
	lastpede->type = HEAD;
	lastpede->pos.y = 18;
	lastpede->speed.y = 1;
	if (rnd(2) == 0) {
	    lastpede->pos.x = 1;
	    lastpede->speed.x = 1;
	} else {
	    lastpede->pos.x = 55;
	    lastpede->speed.x = -1;
	}
	ADDPIECE(lastpede);
	numpedes++;
	if (COMPSPOTS(lastpede->pos, guy))
	    dead = 1;
    }
}

static void poison(PEDE *piece)
{
    do
	piece->poisoned = POISONED;
    while ((piece = piece->next) != NULL && piece->type != HEAD);
}

static void movepedes(void)
{
    register PEDE *piece;
    register int x;
    register char thing;

    for (piece = lastpede; piece != NULL; piece = piece->prev) {	/* move the 'pedes (rev order) */
	piece->oldpos.x = piece->pos.x;
	piece->oldpos.y = piece->pos.y;
	if (piece->type == BODY && (piece == lastpede ||
				    piece->next->type == HEAD)
	    && piece->pos.y == 22 && piece->prev->pos.y == 21
	    && piece->poisoned == UNPOISONED) {
	    piece->type = HEAD;
	    piece->speed.x = -piece->speed.x;
	    if (1 <= piece->pos.x + piece->speed.x &&
		piece->pos.x + piece->speed.x <= 55) {
		piece->pos.x += piece->speed.x;
		if (COMPSPOTS(piece->pos, guy))
		    dead = 1;
	    }
	}
	if (piece->type == BODY) {
	    piece->pos.x = piece->prev->pos.x;
	    piece->pos.y = piece->prev->pos.y;
	    piece->speed.x = piece->prev->speed.x;
	    piece->speed.y = piece->prev->speed.y;
	    if (piece->poisoned == WASPOISONED &&
		piece->prev->poisoned == UNPOISONED)
		piece->poisoned = UNPOISONED;
	} else {
	    x = piece->pos.x + piece->speed.x;
	    if (x < 1 || x > 55 || (thing = mvinch(piece->pos.y, x)) != ' '
		&& thing != YOU && thing != SHOT || piece->overlap
		|| piece->poisoned != UNPOISONED) {
		if (1 <= x && x <= 55
		    && (thing == UNSHOTPOISON || thing == ONCESHOTPOISON
			|| thing == TWICESHOTPOISON))
		    poison(piece);
		piece->speed.x = -piece->speed.x;
		if (piece->pos.y == 22 || (piece->pos.y == 18
					   && piece->speed.y == -1))
		    piece->speed.y = -piece->speed.y;
		piece->pos.y += piece->speed.y;
		piece->overlap = 0;
		if (piece->poisoned == WASPOISONED)
		    piece->poisoned = UNPOISONED;
	    } else
		piece->pos.x = x;
	    if (piece->pos.y == 22 && piece->poisoned == UNPOISONED
		&& !breeding) {
		breeding = 1;
		if (breedtime > 25)
		    breedtime--;
	    }
	}
	if (COMPSPOTS(piece->pos, guy))
	    dead = 1;
	if (piece->poisoned == POISONED && piece->oldpos.y == 22)
	    piece->poisoned = UNPOISONED;
    }
    for (piece = centipede; piece != NULL; piece = piece->next)
	ERASE(piece->oldpos.y, piece->oldpos.x);
    for (piece = centipede; piece != NULL; piece = piece->next) {
	if (mvinch(piece->pos.y, piece->pos.x) == HEAD
	    && piece->type == HEAD)
	    piece->overlap = 1;
	if ((thing = mushw[piece->pos.y][piece->pos.x]) == UNSHOTPOISON
	    || thing == ONCESHOTPOISON || thing == TWICESHOTPOISON)
	    poison(piece);
	ADDPIECE(piece);
    }
}

static void moveflea(void)
{				/* move a flea */
    ERASE(flea.y, flea.x);
    if (flea.y == 22)
	fleahere = 0;
    else {
	if (mushw[flea.y][flea.x] == ' ' && rnd(5) < 2)
	    addshroom(flea.y, flea.x);
	flea.y++;
	mvaddch(flea.y, flea.x, FLEA);
	if (COMPSPOTS(flea, guy))
	    dead = 1;

    }
}

static void startscorp(void)
{				/* start a scorpion */
    if ((scorpvel = rnd(6) - 2) < 1)
	scorpvel--;
    scorppic = (scorpvel > 0) ? rscorpion : lscorpion;
    scorp.x = (scorpvel > 0) ? -5 : 55;
    scorp.y = rnd(12) + 2;
    scorpthisboard = 1;
    scorphere = 1;
    drawpic(&scorppic, 1, 7, scorp.y, scorp.x);
}

static void movescorp(void)
{				/* move a scorpion */
    register int dir, i;

    if (scorpvel > 0) {
	dir = 1;
	i = scorpvel;
    } else {
	dir = -1;
	i = -scorpvel;
    }
    erasepic(1, 7, scorp.y, scorp.x);
    while (i-- && scorphere) {
	if (1 <= scorp.x && scorp.x <= 55)
	    switch (mushw[scorp.y][scorp.x]) {	/* poison a mushroom */
	    case UNSHOTMUSHROOM:
		mvaddch(scorp.y, scorp.x, UNSHOTPOISON);
		mushw[scorp.y][scorp.x] = UNSHOTPOISON;
		break;
	    case ONCESHOTMUSHROOM:
		mvaddch(scorp.y, scorp.x, ONCESHOTPOISON);
		mushw[scorp.y][scorp.x] = ONCESHOTPOISON;
		break;
	    case TWICESHOTMUSHROOM:
		mvaddch(scorp.y, scorp.x, TWICESHOTPOISON);
		mushw[scorp.y][scorp.x] = TWICESHOTPOISON;
		break;
	    }
	scorp.x += dir;
	if (scorp.x < -5 || scorp.x > 55)
	    scorphere = 0;
    }
    if (scorphere)
	drawpic(&scorppic, 1, 7, scorp.y, scorp.x);
}

static void startspider(void)
{
    spiderhere = 1;
    spiderdir = 2 * rnd(2) - 1;
    spider.y = 14;
    spidervel.y = 1;
    if (spiderdir > 0) {
	spider.x = -4;
	spidervel.x = 1;
    } else {
	spider.x = 55;
	spidervel.x = -1;
    }
    drawpic(spiderpic, 2, 6, spider.y, spider.x);
}

static int spidcango(int y, int x)
{
    int yy, xx;

    if (y == 13 || y == 22)
	return (0);
    for (yy = y; yy < y + 2; yy++)
	for (xx = x; xx < x + 6; xx++)
	    if (1 <= xx && xx <= 55 && (mvinch(yy, xx) == HEAD ||
					inch() == BODY))
		return (0);
    return (1);
}

static void movespider(void)
{
    register int y, x, count = 0, dx, dy;

    erasepic(2, 6, spider.y, spider.x);
    while (count++ < 10) {
	y = spider.y + spidervel.y;
	x = spider.x + spidervel.x;
	if (!spidcango(y, x)) {
	    spidervel.y = -spidervel.y;
	    if (rnd(4) < 1)
		spidervel.x = spiderdir - spidervel.x;
	    continue;
	} else {
	    dy = spider.y + 1 - guy.y;
	    dx = spider.x - guy.x;
	    if (dx / spiderdir < 0 && dy && 0 <= (dx + dy) * spiderdir &&
		(dx + dy) * spiderdir <= 5 && rnd(3) < 2) {
		spidervel.x = spiderdir;
		spidervel.y = (dy < 0) ? 1 : -1;
		continue;
	    }
	    if (dx / spiderdir < 0 && rnd(6) < 1) {
		spidervel.x = spiderdir;
		continue;
	    } else if ((spidervel.x && rnd(8) < 1)
		       || (!spidervel.x && rnd(12) < 1)) {
		spidervel.x = spiderdir - spidervel.x;
		continue;
	    } else if (rnd(12) < 1) {
		spidervel.y = -spidervel.y;
		continue;
	    }
	}
	break;
    }
    if (count != 11) {
	spider.y = y;
	spider.x = x;
    } else {
	if (spidcango(spider.y, spider.x + spiderdir) && rnd(12) < 11)
	    spider.x += spiderdir;
	x = spider.x;
	y = spider.y;
    }
    if (x < -4 || x > 55)
	spiderhere = spidcount = 0;
    else {
	int xx;

	for (xx = x + 2; xx <= x + 3; xx++)
	    if (1 <= xx && xx <= 55)
		if (mushw[y + 1][xx] != ' ') {
		    mushw[y + 1][xx] = ' ';
		    if (y >= 17)
			nummushrooms--;
		}
	drawpic(spiderpic, 2, 6, spider.y, spider.x);
	if ((guy.y == spider.y || guy.y == spider.y + 1) &&
	    spider.x <= guy.x && guy.x <= spider.x + 5)
	    dead = 1;
    }
}

static void dofire(void)
{				/* move the guy's shot */
    register int i;

    checkhit();			/* something walked into the shot */
    if (!fired)
	return;
    if (!COMPSPOTS(shot, guy))
	ERASE(shot.y, shot.x);
    for (i = 0; i < 4 && fired; i++) {
	if (!shot.y--) {	/* Shot went off the screen */
	    fired = 0;
	    return;
	}
	checkhit();
    }
    if (fired) {
	mvaddch(shot.y, shot.x, SHOT);
	refresh();
    }
}

static void movestuff(void)
{
    register int y, x;
    int count;

    while (!dead && finished < 40) {
	if (inter)
	    quit();
	if (finished)
	    finished++;
	else {
	    movepedes();
	    if (breeding)
		dobreed();
	}
	if (fleahere)
	    moveflea();
	if ((board >= 2 && !fleahere && !scorphere &&
	     ((rnd(3400) < (board - 1) * fleafreq) ||
	      (nummushrooms < 5 && rnd(600) < (board - 1) * fleafreq))))
	    startflea();
	if (scorphere)
	    movescorp();
	if (board >= 3 && !scorphere && !fleahere &&
	    ((!scorpthisboard && rnd(2000) < board - 1) ||
	     (scorpthisboard && rnd(4000) < board - 1)))
	    startscorp();
	if (spiderhere)
	    movespider();
	spidcount++;
	if (!spiderhere && spidcount % 90 == 0 && rnd(7) < 6)
	    startspider();
	if (fired)
	    dofire();
	getyx(stdscr, y, x);	/* make sure he's not */
	if (mvinch(guy.y, guy.x) != YOU)	/* invisible, but don't */
	    addch(YOU);		/* waste cursor movement */
	move(y, x);
	refresh();
	do
	    count = 0;
	while (count > spiderhere * 40);
	move_guy();
    }
}

static void cleanup_tty(void)
{
    tcsetattr(0, TCSETSW, &origterm);
}

int main(int argc, char *argv[])
{
    if (argc != 1) {
	puts("Usage: cent");
	exit(0);
    }
    tcgetattr(0, &origterm);
    atexit(cleanup_tty);

    instructions();

    signal(SIGQUIT, catchint);
    signal(SIGINT, catchint);

    if (initscr() == NULL) {
	puts("Terminal not smart enough or TERM not set.");
	return 1;
    }

    if (LINES < 24 || COLS < 80) {
	puts("Screen size too small. Size must be at least 24 X 80.");
	exit(0);
    }
    srand(getpid() ^ time(NULL));
    signal(SIGINT, catchint);

    noecho();
    cbreak();
    nonl();
    halfdelay(1);
    make_screen();
    gamestarted = 1;
    while (1) {
	fleafreq = 4 - ((board + 2) % 4);
	make_cent((board - 1) % CENTLENGTH);
	put_pede();
	refresh();
	movestuff();
	if (dead)
	    death();
    }
}
