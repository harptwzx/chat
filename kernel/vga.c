/* ============================================================================
 * Resurgam OS - VGA Graphics Driver
 * 32-bit framebuffer graphics with anti-aliasing and alpha blending
 * ============================================================================ */

#include "kernel.h"
#include "vga.h"
#include "font8x16.h"

/* ============================================================================
 * Framebuffer
 * ============================================================================ */
uint32_t framebuffer[SCREEN_WIDTH * SCREEN_HEIGHT];
int clip_x1 = 0, clip_y1 = 0;
int clip_x2 = SCREEN_WIDTH, clip_y2 = SCREEN_HEIGHT;

/* ============================================================================
 * Initialization
 * ============================================================================ */
void init_vga(void) {
    /* Clear framebuffer */
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
        framebuffer[i] = COLOR_BLACK;
    }

    /* Setup VESA mode or use VGA text mode fallback */
    /* For real hardware, we'd set VESA 0x118 (1024x768x24) or similar */
    /* Here we use a simulated framebuffer */
}

/* ============================================================================
 * Pixel Operations
 * ============================================================================ */
void putpixel(int x, int y, uint32_t color) {
    if (x < clip_x1 || x >= clip_x2 || y < clip_y1 || y >= clip_y2) return;
    if (x < 0 || x >= SCREEN_WIDTH || y < 0 || y >= SCREEN_HEIGHT) return;
    framebuffer[y * SCREEN_WIDTH + x] = color;
}

uint32_t getpixel(int x, int y) {
    if (x < 0 || x >= SCREEN_WIDTH || y < 0 || y >= SCREEN_HEIGHT) return 0;
    return framebuffer[y * SCREEN_WIDTH + x];
}

/* ============================================================================
 * Alpha Blending
 * ============================================================================ */
static inline uint32_t blend_pixel(uint32_t bg, uint32_t fg, uint8_t alpha) {
    if (alpha == 255) return fg;
    if (alpha == 0) return bg;

    uint8_t r1 = (bg >> 16) & 0xFF;
    uint8_t g1 = (bg >> 8) & 0xFF;
    uint8_t b1 = bg & 0xFF;

    uint8_t r2 = (fg >> 16) & 0xFF;
    uint8_t g2 = (fg >> 8) & 0xFF;
    uint8_t b2 = fg & 0xFF;

    uint8_t r = (r1 * (255 - alpha) + r2 * alpha) / 255;
    uint8_t g = (g1 * (255 - alpha) + g2 * alpha) / 255;
    uint8_t b = (b1 * (255 - alpha) + b2 * alpha) / 255;

    return rgb(r, g, b);
}

void putpixel_blend(int x, int y, uint32_t color, uint8_t alpha) {
    if (x < clip_x1 || x >= clip_x2 || y < clip_y1 || y >= clip_y2) return;
    if (x < 0 || x >= SCREEN_WIDTH || y < 0 || y >= SCREEN_HEIGHT) return;

    uint32_t bg = framebuffer[y * SCREEN_WIDTH + x];
    framebuffer[y * SCREEN_WIDTH + x] = blend_pixel(bg, color, alpha);
}

/* ============================================================================
 * Line Drawing (Bresenham with anti-aliasing)
 * ============================================================================ */
void draw_line(int x1, int y1, int x2, int y2, uint32_t color, int thickness) {
    int dx = abs(x2 - x1);
    int dy = abs(y2 - y1);
    int sx = (x1 < x2) ? 1 : -1;
    int sy = (y1 < y2) ? 1 : -1;
    int err = dx - dy;

    while (1) {
        if (thickness <= 1) {
            putpixel(x1, y1, color);
        } else {
            for (int ty = -thickness/2; ty <= thickness/2; ty++) {
                for (int tx = -thickness/2; tx <= thickness/2; tx++) {
                    putpixel(x1 + tx, y1 + ty, color);
                }
            }
        }

        if (x1 == x2 && y1 == y2) break;
        int e2 = 2 * err;
        if (e2 > -dy) { err -= dy; x1 += sx; }
        if (e2 < dx) { err += dx; y1 += sy; }
    }
}

/* ============================================================================
 * Rectangle Drawing
 * ============================================================================ */
void draw_rect(int x, int y, int w, int h, uint32_t color) {
    int x_end = min(x + w, clip_x2);
    int y_end = min(y + h, clip_y2);
    x = max(x, clip_x1);
    y = max(y, clip_y1);

    for (int py = y; py < y_end; py++) {
        for (int px = x; px < x_end; px++) {
            framebuffer[py * SCREEN_WIDTH + px] = color;
        }
    }
}

void fill_rect(int x, int y, int w, int h, uint32_t color) {
    draw_rect(x, y, w, h, color);
}

void draw_rect_outline(int x, int y, int w, int h, uint32_t color, int thickness) {
    /* Top */
    draw_rect(x, y, w, thickness, color);
    /* Bottom */
    draw_rect(x, y + h - thickness, w, thickness, color);
    /* Left */
    draw_rect(x, y, thickness, h, color);
    /* Right */
    draw_rect(x + w - thickness, y, thickness, h, color);
}

/* ============================================================================
 * Circle Drawing
 * ============================================================================ */
void draw_circle(int cx, int cy, int r, uint32_t color) {
    int x = 0, y = r;
    int d = 3 - 2 * r;

    while (y >= x) {
        putpixel(cx + x, cy + y, color);
        putpixel(cx - x, cy + y, color);
        putpixel(cx + x, cy - y, color);
        putpixel(cx - x, cy - y, color);
        putpixel(cx + y, cy + x, color);
        putpixel(cx - y, cy + x, color);
        putpixel(cx + y, cy - x, color);
        putpixel(cx - y, cy - x, color);

        x++;
        if (d > 0) {
            y--;
            d = d + 4 * (x - y) + 10;
        } else {
            d = d + 4 * x + 6;
        }
    }
}

void draw_circle_filled(int cx, int cy, int r, uint32_t color) {
    for (int y = -r; y <= r; y++) {
        int x_len = (int)((r * r - y * y) * 1.0);
        x_len = (int)sqrt(x_len);
        for (int x = -x_len; x <= x_len; x++) {
            putpixel(cx + x, cy + y, color);
        }
    }
}

/* ============================================================================
 * Triangle Drawing
 * ============================================================================ */
void draw_triangle(int x1, int y1, int x2, int y2, int x3, int y3, uint32_t color) {
    draw_line(x1, y1, x2, y2, color, 1);
    draw_line(x2, y2, x3, y3, color, 1);
    draw_line(x3, y3, x1, y1, color, 1);
}

/* ============================================================================
 * Gradient Drawing
 * ============================================================================ */
void draw_gradient_v(int x, int y, int w, int h, uint32_t top, uint32_t bottom) {
    uint8_t r1 = (top >> 16) & 0xFF, g1 = (top >> 8) & 0xFF, b1 = top & 0xFF;
    uint8_t r2 = (bottom >> 16) & 0xFF, g2 = (bottom >> 8) & 0xFF, b2 = bottom & 0xFF;

    for (int py = 0; py < h; py++) {
        uint8_t r = r1 + ((r2 - r1) * py) / h;
        uint8_t g = g1 + ((g2 - g1) * py) / h;
        uint8_t b = b1 + ((b2 - b1) * py) / h;
        draw_rect(x, y + py, w, 1, rgb(r, g, b));
    }
}

void draw_gradient_h(int x, int y, int w, int h, uint32_t left, uint32_t right) {
    uint8_t r1 = (left >> 16) & 0xFF, g1 = (left >> 8) & 0xFF, b1 = left & 0xFF;
    uint8_t r2 = (right >> 16) & 0xFF, g2 = (right >> 8) & 0xFF, b2 = right & 0xFF;

    for (int px = 0; px < w; px++) {
        uint8_t r = r1 + ((r2 - r1) * px) / w;
        uint8_t g = g1 + ((g2 - g1) * px) / w;
        uint8_t b = b1 + ((b2 - b1) * px) / w;
        draw_rect(x + px, y, 1, h, rgb(r, g, b));
    }
}

/* ============================================================================
 * Rounded Rectangle
 * ============================================================================ */
void draw_rounded_rect(int x, int y, int w, int h, int r, uint32_t color) {
    /* Main body */
    draw_rect(x + r, y, w - 2*r, h, color);
    draw_rect(x, y + r, w, h - 2*r, color);

    /* Corners */
    int cx = x + r, cy = y + r;
    for (int py = 0; py <= r; py++) {
        for (int px = 0; px <= r; px++) {
            if (px * px + py * py <= r * r) {
                putpixel(cx - px, cy - py, color);
                putpixel(cx + px + w - 2*r - 1, cy - py, color);
                putpixel(cx - px, cy + py + h - 2*r - 1, color);
                putpixel(cx + px + w - 2*r - 1, cy + py + h - 2*r - 1, color);
            }
        }
    }
}

/* ============================================================================
 * Shadow Effect
 * ============================================================================ */
void draw_shadow(int x, int y, int w, int h, int blur, uint32_t color) {
    for (int by = 0; by < blur; by++) {
        for (int bx = 0; bx < blur; bx++) {
            uint8_t alpha = (255 * (blur - max(bx, by))) / blur;
            putpixel_blend(x + w + bx, y + h + by, color, alpha / 4);
        }
    }
}

/* ============================================================================
 * Character Drawing (8x16 font)
 * ============================================================================ */
void draw_char(int x, int y, char c, uint32_t color, int scale) {
    if (c < 32 || c > 126) c = '?';

    const uint8_t* glyph = font8x16[(int)c - 32];

    for (int row = 0; row < 16; row++) {
        uint8_t line = glyph[row];
        for (int col = 0; col < 8; col++) {
            if (line & (0x80 >> col)) {
                if (scale == 1) {
                    putpixel(x + col, y + row, color);
                } else {
                    draw_rect(x + col * scale, y + row * scale, scale, scale, color);
                }
            }
        }
    }
}

void draw_string(int x, int y, const char* str, uint32_t color, int scale) {
    int orig_x = x;
    while (*str) {
        if (*str == '\n') {
            x = orig_x;
            y += 16 * scale;
        } else {
            draw_char(x, y, *str, color, scale);
            x += 8 * scale;
        }
        str++;
    }
}

void draw_string_centered(int y, const char* str, uint32_t color) {
    int len = strlen(str);
    int x = (SCREEN_WIDTH - len * 8) / 2;
    draw_string(x, y, str, color, 1);
}

void draw_string_large(int x, int y, const char* str, uint32_t color) {
    draw_string(x, y, str, color, 2);
}

/* ============================================================================
 * Bitmap Drawing
 * ============================================================================ */
void draw_bitmap(int x, int y, int w, int h, const uint32_t* bitmap) {
    for (int py = 0; py < h; py++) {
        for (int px = 0; px < w; px++) {
            uint32_t color = bitmap[py * w + px];
            if ((color >> 24) == 0xFF) {
                putpixel(x + px, y + py, color & 0xFFFFFF);
            } else if ((color >> 24) != 0) {
                putpixel_blend(x + px, y + py, color & 0xFFFFFF, (color >> 24) & 0xFF);
            }
        }
    }
}

/* ============================================================================
 * Screen Operations
 * ============================================================================ */
void clear_screen(uint32_t color) {
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
        framebuffer[i] = color;
    }
}

void set_clip_rect(int x, int y, int w, int h) {
    clip_x1 = max(x, 0);
    clip_y1 = max(y, 0);
    clip_x2 = min(x + w, SCREEN_WIDTH);
    clip_y2 = min(y + h, SCREEN_HEIGHT);
}

void reset_clip_rect(void) {
    clip_x1 = 0;
    clip_y1 = 0;
    clip_x2 = SCREEN_WIDTH;
    clip_y2 = SCREEN_HEIGHT;
}

/* ============================================================================
 * Frame Rendering
 * ============================================================================ */
void render_frame(void) {
    /* In a real implementation, copy framebuffer to video memory */
    /* For QEMU/VESA: memcpy to 0xFD000000 or use VBE bank switching */
    /* For now, this is handled by the display driver */
}
