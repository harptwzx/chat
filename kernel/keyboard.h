/* ============================================================================
 * Resurgam OS - Keyboard Driver Header
 * ============================================================================ */

#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "kernel.h"

#define KEYBOARD_DATA_PORT    0x60
#define KEYBOARD_STATUS_PORT  0x64
#define KEYBOARD_CMD_PORT     0x64

#define KEY_BUFFER_SIZE       256

/* Special keys */
#define KEY_ESC        0x01
#define KEY_ENTER      0x1C
#define KEY_BACKSPACE  0x0E
#define KEY_TAB        0x0F
#define KEY_SPACE      0x39
#define KEY_LSHIFT     0x2A
#define KEY_RSHIFT     0x36
#define KEY_LCTRL      0x1D
#define KEY_LALT       0x38
#define KEY_CAPS       0x3A
#define KEY_UP         0x48
#define KEY_DOWN       0x50
#define KEY_LEFT       0x4B
#define KEY_RIGHT      0x4D
#define KEY_F1         0x3B
#define KEY_F2         0x3C
#define KEY_F3         0x3D
#define KEY_F4         0x3E
#define KEY_F5         0x3F
#define KEY_F6         0x40
#define KEY_F7         0x41
#define KEY_F8         0x42
#define KEY_F9         0x43
#define KEY_F10        0x44
#define KEY_F11        0x57
#define KEY_F12        0x58
#define KEY_HOME       0x47
#define KEY_END        0x4F
#define KEY_PGUP       0x49
#define KEY_PGDN       0x51
#define KEY_DEL        0x53
#define KEY_INSERT     0x52

/* Modifier states */
extern volatile int key_shift;
extern volatile int key_ctrl;
extern volatile int key_alt;
extern volatile int key_caps;

/* Key buffer */
extern volatile char key_buffer[KEY_BUFFER_SIZE];
extern volatile int key_buffer_head;
extern volatile int key_buffer_tail;
extern volatile int key_buffer_count;

/* Functions */
void init_keyboard(void);
void keyboard_handler(void);
char get_key(void);
int key_available(void);
void keyboard_wait(void);
const char* get_key_name(uint8_t scancode);

#endif
