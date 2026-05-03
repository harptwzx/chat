/* ============================================================================
 * Resurgam OS - VGA Text Mode Console
 * Fallback console for debugging and early boot
 * ============================================================================ */

#include "kernel.h"
#include "console.h"

/* VGA text buffer */
static uint16_t* vga_buffer = (uint16_t*)0xB8000;
static int console_x = 0;
static int console_y = 0;
static uint8_t console_color = CONSOLE_COLOR;

/* ============================================================================
 * Initialize Console
 * ============================================================================ */
void init_console(void) {
    console_x = 0;
    console_y = 0;
    console_color = CONSOLE_COLOR;
    console_clear();
}

/* ============================================================================
 * Clear Console
 * ============================================================================ */
void console_clear(void) {
    for (int i = 0; i < CONSOLE_WIDTH * CONSOLE_HEIGHT; i++) {
        vga_buffer[i] = (console_color << 8) | ' ';
    }
    console_x = 0;
    console_y = 0;
    console_update_cursor();
}

/* ============================================================================
 * Put Character
 * ============================================================================ */
void console_putchar(char c) {
    if (c == '\n') {
        console_x = 0;
        console_y++;
    } else if (c == '\r') {
        console_x = 0;
    } else if (c == '\t') {
        console_x = (console_x + 8) & ~7;
    } else if (c == '\b') {
        if (console_x > 0) console_x--;
    } else {
        vga_buffer[console_y * CONSOLE_WIDTH + console_x] = (console_color << 8) | c;
        console_x++;
    }

    if (console_x >= CONSOLE_WIDTH) {
        console_x = 0;
        console_y++;
    }

    if (console_y >= CONSOLE_HEIGHT) {
        console_scroll();
    }

    console_update_cursor();
}

/* ============================================================================
 * Put String
 * ============================================================================ */
void console_puts(const char* str) {
    while (*str) {
        console_putchar(*str++);
    }
}

/* ============================================================================
 * Put Hex
 * ============================================================================ */
void console_puthex(uint32_t n) {
    console_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint8_t digit = (n >> i) & 0xF;
        if (digit < 10) {
            console_putchar('0' + digit);
        } else {
            console_putchar('A' + digit - 10);
        }
    }
}

/* ============================================================================
 * Put Decimal
 * ============================================================================ */
void console_putdec(uint32_t n) {
    if (n == 0) {
        console_putchar('0');
        return;
    }

    char buf[12];
    int i = 0;
    while (n > 0) {
        buf[i++] = '0' + (n % 10);
        n /= 10;
    }

    while (i > 0) {
        console_putchar(buf[--i]);
    }
}

/* ============================================================================
 * Set Color
 * ============================================================================ */
void console_set_color(uint8_t color) {
    console_color = color;
}

/* ============================================================================
 * Goto Position
 * ============================================================================ */
void console_goto(int x, int y) {
    if (x >= 0 && x < CONSOLE_WIDTH) console_x = x;
    if (y >= 0 && y < CONSOLE_HEIGHT) console_y = y;
    console_update_cursor();
}

/* ============================================================================
 * Scroll
 * ============================================================================ */
void console_scroll(void) {
    /* Move lines up */
    for (int y = 0; y < CONSOLE_HEIGHT - 1; y++) {
        for (int x = 0; x < CONSOLE_WIDTH; x++) {
            vga_buffer[y * CONSOLE_WIDTH + x] = vga_buffer[(y + 1) * CONSOLE_WIDTH + x];
        }
    }

    /* Clear last line */
    for (int x = 0; x < CONSOLE_WIDTH; x++) {
        vga_buffer[(CONSOLE_HEIGHT - 1) * CONSOLE_WIDTH + x] = (console_color << 8) | ' ';
    }

    console_y = CONSOLE_HEIGHT - 1;
}

/* ============================================================================
 * Update Cursor
 * ============================================================================ */
void console_update_cursor(void) {
    uint16_t pos = console_y * CONSOLE_WIDTH + console_x;

    outb(0x3D4, 0x0F);
    outb(0x3D5, pos & 0xFF);
    outb(0x3D4, 0x0E);
    outb(0x3D5, (pos >> 8) & 0xFF);
}
