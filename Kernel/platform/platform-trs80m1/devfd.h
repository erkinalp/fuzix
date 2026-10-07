#ifndef __DEVFD_DOT_H__
#define __DEVFD_DOT_H__

/* public interface */
int fd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int fd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
int fd_open(uint_fast8_t minor, uint16_t flag);
int fd_ioctl(uint_fast8_t minor, uarg_t request, char *buffer);

/* low level interface */
uint8_t fd_restore(uint8_t *driveptr);
uint16_t fd_operation(uint8_t *driveptr);
uint16_t fd_motor_on(uint16_t drivesel);

/* low level interface */
uint8_t fd3_restore(uint8_t *driveptr);
uint16_t fd3_operation(uint8_t *driveptr);
uint16_t fd3_motor_on(uint16_t drivesel);

struct fd_ops {
    uint8_t (*fd_restore)(uint8_t *driveptr);
    uint16_t (*fd_op)(uint8_t *driveptr);
    uint16_t (*fd_motor_on)(uint16_t drivesel);
};

#endif /* __DEVFD_DOT_H__ */
