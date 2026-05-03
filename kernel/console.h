/* ============================================================================
 * Resurgam OS - Console Driver Header
 * ============================================================================ */

#ifndef CONSOLE_H
#define CONSOLE_H

#include "kernel.h"

#define CONSOLE_WIDTH   80
#define CONSOLE_HEIGHT  25
#define CONSOLE_COLOR   0x0F

/* VGA text mode colors */
#define VGA_BLACK       0x00
#define VGA_BLUE        0x01
#define VGA_GREEN       0x02
#define VGA_CYAN        0x03
#define VGA_RED         0x04
#define VGA_MAGENTA     0x05
#define VGA_BROWN       0x06
#define VGA_LIGHT_GRAY  0x07
#define VGA_DARK_GRAY   0x08
#define VGA_LIGHT_BLUE  0x09
#define VGA_LIGHT_GREEN 0x0A
#define VGA_LIGHT_CYAN  0x0B
#define VGA_LIGHT_RED   0x0C
#define VGA_LIGHT_MAGENTA 0x0D
#define VGA_YELLOW      0x0E
#define VGA_WHITE       0x0F

/* Functions */
void init_console(void);
void console_clear(void);
void console_putchar(char c);
void console_puts(const char* str);
void console_puthex(uint32_t n);
void console_putdec(uint32_t n);
void console_set_color(uint8_t color);
void console_goto(int x, int y);
void console_scroll(void);
void console_update_cursor(void);

#endif
