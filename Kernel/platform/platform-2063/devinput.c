#include <kernel.h>
#include <kdata.h>
#include <input.h>
#include <devinput.h>
#include <ps2mouse.h>

#define JS1	0xA8
#define JS2	0xA9

static uint8_t js_data[2]= {255, 255};

uint8_t read_js(uint8_t *slot, uint8_t n)
{
    uint8_t d = 0;
    uint8_t r = in(JS1 + n) & 63;
    if (r == js_data[n])
        return 0;
    js_data[n] = r;
    r ^= 0xFF;
    if (r & 0x80)
        d = STICK_DIGITAL_U;
    if (r & 0x40)
        d |= STICK_DIGITAL_D;
    if (r & 0x4)
        d |= STICK_DIGITAL_L;
    if (r & 0x20)
        d |= STICK_DIGITAL_R;
    if (r & 1)
        d |= BUTTON(0);
    *slot++ = STICK_DIGITAL | (n + 1);
    *slot = d;
    return 2;
}

int plt_input_read(uint8_t *slot)
{
    if (read_js(slot, 0))
        return 2;
    if (read_js(slot, 1))
        return 2;
    return 0;
}

void plt_input_wait(void)
{
    psleep(js_data);	/* We wake this on timers so it works for sticks */
}

void poll_input(void)
{
    if ((in(JS1) & 63) != js_data[0] ||
        ((in(JS2) & 63) != js_data[1]))
            wakeup(js_data);
}

int plt_input_write(uint_fast8_t flag)
{
    flag;
    udata.u_error = EINVAL;
    return -1;
}
