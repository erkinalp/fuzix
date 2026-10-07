/*

Fuzix Sudoku Alan Cox 2026

Reworked to remove a lot of duplicated code, to support the older
curses styles, use ACS symbols and also fit a small screen so
Ciaran can play.

Derived from nsudoku 1.3

Copyright (c) 2008-2015 Tin Benjamin Matuka

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

To compile nsudoku run
$ gcc -o nsudoku nsudoku.c -lncurses

I have no intention of updating this game, because I made it
just to learn how to work with ncurses. You can use the code
if you want to.

For more information visit nsudoku web site:
http://www.tbmatuka.com/nsudoku

I can be contacted at mail[at]tbmatuka[dot]com


*/
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <ncurses.h>
#include <string.h>
#include <getopt.h>

#define CTRL(c) ((c) & 037)
#define VERSION "1.3ac2"

int board[9][9], start[9][9];
WINDOW *helpbox, *win;

int check(void);		// check if all numbers in board array match the rules
void clear_grid(int i, int j);	// clear a grid(3x3) in row i and column j
int count(void);		// count how many values are in board array
void generate(int n);		// generate sudoku
int stdprint(void);		// stdout print board array
int helpboxon(void);		// turn help box on
int helpboxoff(void);		// turn help box off
int restart(void);
void printhelp(void);
void printversion(void);

static unsigned cellsize = 3;	/* Grouping for cells */
static unsigned wy = 0;

static void pad_box(int pad)
{
	unsigned n = cellsize;
	while (n--)
		waddch(win, pad);
}

static void drawline(int left, int mid, int right, int pad)
{
	wmove(win, wy++, 0);
	waddch(win, left);
	pad_box(pad);
	waddch(win, mid);
	pad_box(pad);
	waddch(win, mid);
	pad_box(pad);
	waddch(win, right);
}

static void drawvert(void)
{
	unsigned n = cellsize;
	while (n--)
		drawline(ACS_VLINE, ACS_VLINE, ACS_VLINE, ' ');
}

static void render(void)
{
	wmove(win, 0, 0);
	drawline(ACS_ULCORNER, ACS_TTEE, ACS_URCORNER, ACS_HLINE);
	drawvert();
	drawline(ACS_LTEE, ACS_PLUS, ACS_RTEE, ACS_HLINE);
	drawvert();
	drawline(ACS_LTEE, ACS_PLUS, ACS_RTEE, ACS_HLINE);
	drawvert();
	drawline(ACS_LLCORNER, ACS_BTEE, ACS_LRCORNER, ACS_HLINE);
}

static void move_to_cell(unsigned y, unsigned x)
{
	if (x >= 2 * cellsize)
		x++;
	if (x >= cellsize)
		x++;
	if (y >= 2 * cellsize)
		y++;
	if (y >= cellsize)
		y++;
	wmove(win, y + 1, x + 1);
}

static void draw_cell(unsigned y, unsigned x, int c)
{
	move_to_cell(y, x);
	waddch(win, " 123456789"[c]);
}

static void show_cells(void)
{
	unsigned y, x;
	int *b = &board[0][0];
	for (y = 0; y < 9; y++) {
		for (x = 0; x < 9; x++)
			draw_cell(y, x, *b++);
	}
}

static void usage(void)
{
	fputs("sudoku [-v] [-h] [-p] num\n", stderr);
	exit(1);
}

int main(int argc, char *argv[])
{
	int n = 0, print = 1;
	int ch, hb = 1;
	int posx = 0, posy = 0;
	int opt;
	unsigned over = 0;

	srand(time(NULL));

	while ((opt = getopt(argc, argv, "vhp")) != -1) {
		switch (opt) {
		case 'v':
			printversion();
			return 0;
		case 'h':
			printhelp();
			return 0;
		case 'p':
			print = 0;
			break;
		default:
			usage();
		}
	}
	if (argv[optind])
		n = atoi(argv[optind++]);
	if (argv[optind])
		usage();

	if (n < 1 || n > 80)
		n = 40;
	generate(n);
	if (initscr() == NULL) {
		fputs("sudoku: terminal unsuitable\n", stderr);
		return 1;
	}
	noecho();
	keypad(stdscr, TRUE);
	cbreak();
	win = newwin(13, 13, 1, 16);
	helpbox = newwin(12, 15, 1, 1);
	werase(win);
	refresh();
	render();
	show_cells();
	helpboxon();
	wmove(win, 1, 1);
	wrefresh(win);
	while (!over && (ch = wgetch(win)) != 'q' && ch != ERR) {
		switch (ch) {
		case 'r':
			restart();
			break;
			/* Q: would it feel nicer to wrap ? */
		case 'l':
			if (posx < 8)
				posx++;
			break;
		case 'h':
			if (posx)
				posx--;
			break;
		case 'j':
			if (posy < 8)
				posy++;
			break;
		case 'k':
			if (posy)
				posy--;
			break;
		case 127:
		case '\b':
			if (start[posy][posx] == 0) {
				board[posy][posx] = 0;
				draw_cell(posy, posx, ' ');
			}
			break;
		case '?':
			if (hb == 1)
				helpboxoff();
			else
				helpboxon();
			hb ^= 1;
			refresh();
			break;
		case CTRL('L'):
		case CTRL('R'):
			touchwin(win);
			touchwin(stdscr);
			refresh();
			wrefresh(win);
			break;
		default:
			if (ch > '0' && ch <= '9') {
				if (start[posy][posx] == 0) {
					board[posy][posx] = ch - '0';
					draw_cell(posy, posx, ch - '0');
				}
			}
		}
		move_to_cell(posy, posx);
		wrefresh(win);
		if (check() == 1 && count() == 81)
			over = 1;
	}
	endwin();
	if (over)
		puts("Congratulations, you won the game!");
	if (print == 1)
		stdprint();
	return 0;
}

int helpboxon(void)
{
	wprintw(helpbox,
		"Help\nq - quit\nr - restart\n? - Show Help\n\nmovement:\n - hjkl\n\ndelete:\n - delete\n - backspace");
	wrefresh(helpbox);
	return 0;
}

int helpboxoff(void)
{
	werase(helpbox);
	wrefresh(helpbox);
	return 0;
}

int check(void)
{
	int i, j, k, l, x, y;
	int c1[10], c2[10];

	/* Sweep horizontally and vertically in one pass */
	for (i = 0; i < 9; i++) {
		for (k = 1; k < 10; k++) {
			c1[k] = 0;
			c2[k] = 0;
		}
		for (j = 0; j < 9; j++) {
			if (board[i][j] != 0)
				if (c1[board[i][j]]++)
					return 0;
			if (board[j][i] != 0)
				if (c2[board[j][i]]++)
					return 0;
		}
	}
	/* And check the cubes */
	for (i = 0; i < 3; i++) {
		for (j = 0; j < 3; j++) {
			for (x = 1; x < 10; x++) {
				c1[x] = 0;
				c2[x] = 0;
			}
			for (k = 0; k < 3; k++) {
				for (l = 0; l < 3; l++) {
					x = (i * 3) + k;
					y = (j * 3) + l;
					if (board[x][y] != 0)
						if (c1[board[x][y]]++)
							return 0;
					if (board[y][x] != 0)
						if (c2[board[y][x]]++)
							return 0;
				}
			}
		}
	}
	return 1;
}

void clear_grid(int i, int j)
{
	int k, l, x, y;

	for (k = 0; k < 3; k++)
		for (l = 0; l < 3; l++) {
			x = (i * 3) + k;
			y = (j * 3) + l;
			board[x][y] = 0;
		}
}

int solve_grid(int i, int j)
{
	int k, l, x, y, z;
	for (k = 0; k < 3; k++)
		for (l = 0; l < 3; l++) {
			x = (i * 3) + k;
			y = (j * 3) + l;
			for (z = 1; z < 10; z++) {
				board[x][y] = z;
				if (check() == 1)
					z = 10;
			}
		}
	return 0;
}

int count(void)
{
	int i, j, ret = 0;
	for (i = 0; i < 9; i++)
		for (j = 0; j < 9; j++)
			if (board[i][j] > 0)
				ret++;
	return ret;
}

int stdprint(void)
{
	int i, j;
	for (i = 0; i < 9; i++) {
		if ((i % 3) == 0)
			printf("+---+---+---+\n");
		for (j = 0; j < 9; j++) {
			if ((j % 3) == 0)
				printf("|");
			if (board[i][j] != 0)
				printf("%d", board[i][j]);
			else
				printf(" ");
		}
		printf("|\n");
	}
	printf("+---+---+---+\n");
	return 0;
}

void generate(int n)
{
	int i, j, k, l, r1, r2, x, y, z, num;

	memset(&start[0][0], 0, sizeof(start));

	while (check() == 0 || count() < 80) {
		for (i = 0; i < 3; i++)
			for (j = 0; j < 3; j++)
				clear_grid(i, j);
		for (r1 = 0, i = 0; i < 3 && r1 < 50; i++, r1++) {
			for (r2 = 0, j = 0; j < 3 && r2 < 100; j++, r2++) {
				for (k = 0; k < 3; k++) {
					for (l = 0; l < 3; l++) {
						x = (i * 3) + k;
						y = (j * 3) + l;
						num = (rand() >> 2) % 9 + 1;
						for (z = 0; z < 9; z++, num++) {
							if (num == 10)
								num = 1;
							board[x][y] = num;
							if (check() == 1)
								z = 10;
						}
					}
				}
				if (check() == 0) {
					if (i == 2 && j == 2)
						solve_grid(2, 2);
					else {
						clear_grid(i, j);
						j--;
					}
				}
			}
			if (check() == 0) {
				for (j = 0; j < 3; j++)
					clear_grid(i, j);
				i--;
			}
		}
		putchar('.');
		fflush(stdout);
	}
	for (i = 0; i < n; i++) {
		z = 0;
		while (z == 0) {
			x = ((int) rand()) % 9;
			y = ((int) rand()) % 9;
			if (start[x][y] == 0) {
				start[x][y] = board[x][y];
				z = 1;
			}
		}
	}
	memcpy(&board[0][0], &start[0][0], sizeof(board));
	putchar('\n');
}

int restart(void)
{
	memcpy(&board[0][0], &start[0][0], sizeof(board));
	show_cells();
	wrefresh(win);
	return 0;
}

void printhelp(void)
{
	printf("Usage: nsudoku [OPTION...] [SOLVED]\n\n");
	printf
	    (" SOLVED is the number of presolved cells. Default: 40\n\n");
	printf("  -p, --no-print    don't print on exit\n");
	printf("  -h, --help give   this help list\n");
	printf("  -v, --version     print program version\n\n");
	printf("For more information visit www.tbmatuka.com/nsudoku\n");
}

void printversion(void)
{
	printf("nsudoku %s\n", VERSION);
}
