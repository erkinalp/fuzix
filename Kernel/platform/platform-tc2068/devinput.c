/*
 *	Joysticks off the AY sound chip
 */
#include <kernel.h>
#include <kdata.h>
#include <input.h>
#include <devinput.h>

static uint8_t ay_p1_save, ay_p2_save;

#define	AY_REG		0xF5
#define AY_PLAYER1	0x01F6
#define AY_PLAYER2	0x02F6

static char buf[32];

static struct s_queue kqueue = {
 buf, buf, buf, sizeof(buf), 0, sizeof(buf) / 2
};

/* Queue a character to the input device */
void queue_input(uint8_t c)
{
    insq(&kqueue, c);
    wakeup(&kqueue);
}

static uint8_t ay_encode(uint8_t r)
{
    uint8_t k = 0;
    r = ~r;
    if (r & 1)
        k = STICK_DIGITAL_U;
    if (r & 2)
        k |= STICK_DIGITAL_D;
    if (r & 4)
        k |= STICK_DIGITAL_L;
    if (r & 8)
        k |= STICK_DIGITAL_R;
    if (r & 128)
        k |= BUTTON(0);
    return k;
}

static uint8_t ay_js(uint8_t *slot)
{
    uint8_t r = in(AY_PLAYER1);
    if (r == ay_p1_save)
        return 0;
    ay_p1_save = r;
    *slot++ = STICK_DIGITAL;
    *slot = ay_encode(r);
    return 2;
}

static uint8_t ay_js2(uint8_t *slot)
{
    uint8_t r = in(AY_PLAYER2);
    if (r == ay_p2_save)
        return 0;
    ay_p2_save = r;
    *slot++ = STICK_DIGITAL | 1;
    *slot = ay_encode(r);
    return 2;
}

int plt_input_read(uint8_t *slot)
{
    uint_fast8_t r, k;
    if (remq(&kqueue, &r)) {
        remq(&kqueue, &k);
	*slot++ = KEYPRESS_CODE | r;
	*slot = k;
	return 2;
    }

    out(AY_REG, 0x0E);
    if (ay_js(slot))
        return 2;
    if (ay_js2(slot))
        return 2;
    return 0;
}

void plt_input_wait(void)
{
    psleep(&kqueue);	/* We wake this on timers so it works for sticks */
}

int plt_input_write(uint_fast8_t flag)
{
    flag;
    udata.u_error = EINVAL;
    return -1;
}

void poll_input(void)
{
    out(AY_REG, 0x0E);
    if (in(AY_PLAYER1) != ay_p1_save || in(AY_PLAYER2) != ay_p2_save)
        wakeup(&kqueue);
}
