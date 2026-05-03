/* ============================================================================
 * Resurgam OS - PS/2 Mouse Driver Header
 * ============================================================================ */

#ifndef MOUSE_H
#define MOUSE_H

#include "kernel.h"

#define MOUSE_DATA_PORT     0x60
#define MOUSE_STATUS_PORT   0x64
#define MOUSE_CMD_PORT      0x64

/* Mouse packet structure */
typedef struct {
    int x;
    int y;
    int buttons;
    int scroll;
    int present;
} mouse_state_t;

/* Button states */
#define MOUSE_LEFT      0x01
#define MOUSE_RIGHT     0x02
#define MOUSE_MIDDLE    0x04
#define MOUSE_BUTTON4   0x08
#define MOUSE_BUTTON5   0x10

/* Mouse state */
extern mouse_state_t mouse;
extern volatile int mouse_packet_ready;

/* Functions */
void init_mouse(void);
void mouse_handler(void);
void process_mouse(void);
void mouse_wait(uint8_t type);
void mouse_write(uint8_t data);
uint8_t mouse_read(void);

#endif
