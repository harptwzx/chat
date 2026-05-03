/* ============================================================================
 * Resurgam OS - VGA Graphics Driver Header
 * ============================================================================ */

#ifndef VGA_H
#define VGA_H

#include "kernel.h"

/* ============================================================================
 * VGA Functions
 * ============================================================================ */
void init_vga(void);
void putpixel(int x, int y, uint32_t color);
uint32_t getpixel(int x, int y);
void draw_line(int x1, int y1, int x2, int y2, uint32_t color, int thickness);
void draw_rect(int x, int y, int w, int h, uint32_t color);
void draw_rect_outline(int x, int y, int w, int h, uint32_t color, int thickness);
void draw_circle(int cx, int cy, int r, uint32_t color);
void draw_circle_filled(int cx, int cy, int r, uint32_t color);
void draw_triangle(int x1, int y1, int x2, int y2, int x3, int y3, uint32_t color);
void draw_char(int x, int y, char c, uint32_t color, int scale);
void draw_string(int x, int y, const char* str, uint32_t color, int scale);
void draw_string_centered(int y, const char* str, uint32_t color);
void draw_string_large(int x, int y, const char* str, uint32_t color);
void draw_bitmap(int x, int y, int w, int h, const uint32_t* bitmap);
void clear_screen(uint32_t color);
void fill_rect(int x, int y, int w, int h, uint32_t color);
void draw_gradient_v(int x, int y, int w, int h, uint32_t top, uint32_t bottom);
void draw_gradient_h(int x, int y, int w, int h, uint32_t left, uint32_t right);
void draw_rounded_rect(int x, int y, int w, int h, int r, uint32_t color);
void draw_shadow(int x, int y, int w, int h, int blur, uint32_t color);
void set_clip_rect(int x, int y, int w, int h);
void reset_clip_rect(void);
void render_frame(void);

/* Framebuffer */
extern uint32_t* framebuffer;
extern int clip_x1, clip_y1, clip_x2, clip_y2;

#endif
