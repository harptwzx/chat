/* ============================================================================
 * Resurgam OS - Kernel Main
 * 32-bit GUI Operating System
 * ============================================================================ */

#include "kernel.h"
#include "vga.h"
#include "console.h"
#include "mouse.h"
#include "keyboard.h"
#include "timer.h"
#include "idt.h"
#include "gdt.h"
#include "paging.h"
#include "task.h"
#include "vfs.h"
#include "shell.h"
#include "window.h"
#include "desktop.h"

/* ============================================================================
 * Kernel Entry Point
 * ============================================================================ */
void kernel_main(void) {
    /* Initialize serial for debugging */
    init_serial();
    kprintf("Resurgam OS v1.0 - Kernel starting...\n");

    /* Setup GDT */
    init_gdt();
    kprintf("[OK] GDT initialized\n");

    /* Setup IDT and interrupts */
    init_idt();
    kprintf("[OK] IDT initialized\n");

    /* Setup PIT timer (1000Hz) */
    init_timer(1000);
    kprintf("[OK] Timer initialized (1000Hz)\n");

    /* Setup keyboard */
    init_keyboard();
    kprintf("[OK] Keyboard initialized\n");

    /* Setup mouse */
    init_mouse();
    kprintf("[OK] Mouse initialized\n");

    /* Enable paging */
    init_paging();
    kprintf("[OK] Paging initialized\n");

    /* Initialize VFS */
    init_vfs();
    kprintf("[OK] VFS initialized\n");

    /* Initialize tasking */
    init_tasking();
    kprintf("[OK] Tasking initialized\n");

    /* Initialize graphics */
    init_vga();
    kprintf("[OK] VGA initialized\n");

    /* Show boot screen */
    show_boot_screen();

    /* Initialize window manager */
    init_window_manager();
    kprintf("[OK] Window manager initialized\n");

    /* Initialize desktop */
    init_desktop();
    kprintf("[OK] Desktop initialized\n");

    /* Initialize shell */
    init_shell();
    kprintf("[OK] Shell initialized\n");

    /* Enable interrupts */
    asm volatile("sti");
    kprintf("[OK] Interrupts enabled\n");

    kprintf("\nResurgam OS is ready.\n");

    /* Enter main loop */
    main_loop();
}

/* ============================================================================
 * Main GUI Loop
 * ============================================================================ */
void main_loop(void) {
    while (1) {
        /* Process mouse input */
        process_mouse();

        /* Process keyboard input */
        process_keyboard();

        /* Update window manager */
        update_windows();

        /* Render frame */
        render_frame();

        /* Small delay to prevent CPU spinning too fast */
        asm volatile("hlt");
    }
}

/* ============================================================================
 * Boot Screen
 * ============================================================================ */
void show_boot_screen(void) {
    /* Clear screen with gradient blue */
    for (int y = 0; y < SCREEN_HEIGHT; y++) {
        uint8_t r = 0;
        uint8_t g = (y * 40) / SCREEN_HEIGHT;
        uint8_t b = 80 + (y * 100) / SCREEN_HEIGHT;
        for (int x = 0; x < SCREEN_WIDTH; x++) {
            putpixel(x, y, rgb(r, g, b));
        }
    }

    /* Draw logo */
    draw_logo(SCREEN_WIDTH / 2 - 150, SCREEN_HEIGHT / 2 - 100);

    /* Draw progress bar background */
    int bar_x = SCREEN_WIDTH / 2 - 150;
    int bar_y = SCREEN_HEIGHT / 2 + 80;
    int bar_w = 300;
    int bar_h = 20;

    draw_rect(bar_x - 2, bar_y - 2, bar_w + 4, bar_h + 4, rgb(200, 200, 200));
    draw_rect(bar_x, bar_y, bar_w, bar_h, rgb(30, 30, 50));

    /* Animate progress bar */
    for (int i = 0; i <= bar_w; i += 3) {
        draw_rect(bar_x, bar_y, i, bar_h, rgb(100, 150, 255));
        draw_rect(bar_x + i, bar_y, 1, bar_h, rgb(150, 200, 255));

        /* Draw loading text */
        char* loading_text = "Loading Resurgam OS...";
        draw_string_centered(bar_y + 35, loading_text, rgb(200, 200, 220));

        /* Draw version */
        draw_string_centered(bar_y + 55, "Version 1.0 - Build 2026.04.29", rgb(150, 150, 180));

        /* Small delay */
        for (volatile int d = 0; d < 500000; d++);
    }

    /* Fade out */
    for (int fade = 0; fade < 10; fade++) {
        for (volatile int d = 0; d < 300000; d++);
    }
}

/* ============================================================================
 * Logo Drawing
 * ============================================================================ */
void draw_logo(int x, int y) {
    /* Draw stylized 'R' logo */
    int cx = x + 150;
    int cy = y + 60;

    /* Outer circle */
    draw_circle(cx, cy, 55, rgb(100, 150, 255));
    draw_circle(cx, cy, 53, rgb(120, 170, 255));

    /* Inner circle */
    draw_circle(cx, cy, 45, rgb(80, 130, 230));

    /* Letter R */
    draw_line(cx - 20, cy - 25, cx - 20, cy + 25, rgb(255, 255, 255), 4);
    draw_line(cx - 20, cy - 25, cx + 5, cy - 25, rgb(255, 255, 255), 4);
    draw_line(cx + 5, cy - 25, cx + 15, cy - 15, rgb(255, 255, 255), 4);
    draw_line(cx + 15, cy - 15, cx + 15, cy - 5, rgb(255, 255, 255), 4);
    draw_line(cx + 15, cy - 5, cx - 5, cy + 5, rgb(255, 255, 255), 4);
    draw_line(cx - 5, cy + 5, cx + 20, cy + 25, rgb(255, 255, 255), 4);

    /* System name */
    draw_string_large(cx - 100, cy + 70, "Resurgam OS", rgb(220, 230, 255));
}

/* ============================================================================
 * Serial Output (for debugging)
 * ============================================================================ */
void init_serial(void) {
    outb(0x3F8 + 1, 0x00);
    outb(0x3F8 + 3, 0x80);
    outb(0x3F8 + 0, 0x03);
    outb(0x3F8 + 1, 0x00);
    outb(0x3F8 + 3, 0x03);
    outb(0x3F8 + 2, 0xC7);
    outb(0x3F8 + 4, 0x0B);
}

void serial_putc(char c) {
    while ((inb(0x3F8 + 5) & 0x20) == 0);
    outb(0x3F8, c);
}

void kprintf(const char* fmt, ...) {
    while (*fmt) {
        serial_putc(*fmt);
        fmt++;
    }
}
