/* ============================================================================
 * Resurgam OS - Window Manager
 * Modern GUI with shadows, gradients, and smooth animations
 * ============================================================================ */

#include "kernel.h"
#include "vga.h"
#include "window.h"
#include "desktop.h"

/* Window list */
window_t* window_list = 0;
window_t* active_window = 0;
int window_count = 0;
int next_window_id = 1;

/* Mouse cursor */
int cursor_x = 0, cursor_y = 0;
uint32_t cursor_color = COLOR_WHITE;

/* Drag state */
static window_t* drag_window = 0;
static int drag_offset_x = 0;
static int drag_offset_y = 0;
static int drag_mode = 0;

/* ============================================================================
 * Initialize Window Manager
 * ============================================================================ */
void init_window_manager(void) {
    window_list = 0;
    active_window = 0;
    window_count = 0;
    next_window_id = 1;
    cursor_x = SCREEN_WIDTH / 2;
    cursor_y = SCREEN_HEIGHT / 2;
}

/* ============================================================================
 * Create Window
 * ============================================================================ */
window_t* create_window(const char* title, int x, int y, int w, int h, uint32_t flags) {
    if (window_count >= MAX_WINDOWS) return 0;

    window_t* wnd = (window_t*)kmalloc(sizeof(window_t));
    if (!wnd) return 0;

    memset(wnd, 0, sizeof(window_t));

    wnd->id = next_window_id++;
    wnd->x = x;
    wnd->y = y;
    wnd->width = (w < WINDOW_MIN_W) ? WINDOW_MIN_W : w;
    wnd->height = (h < WINDOW_MIN_H) ? WINDOW_MIN_H : h;
    wnd->prev_x = x;
    wnd->prev_y = y;
    wnd->prev_w = wnd->width;
    wnd->prev_h = wnd->height;
    wnd->flags = flags | WF_VISIBLE | WF_CLOSEABLE;
    wnd->bg_color = rgb(240, 240, 245);
    wnd->title_color = rgb(60, 120, 200);

    strncpy(wnd->title, title, 63);
    wnd->title[63] = '\0';

    /* Allocate content buffer */
    wnd->content_w = wnd->width - WINDOW_BORDER * 2;
    wnd->content_h = wnd->height - WINDOW_TITLE_H - WINDOW_BORDER * 2;
    wnd->content = (uint32_t*)kmalloc(wnd->content_w * wnd->content_h * sizeof(uint32_t));
    if (wnd->content) {
        for (int i = 0; i < wnd->content_w * wnd->content_h; i++) {
            wnd->content[i] = wnd->bg_color;
        }
    }

    /* Add to window list (top) */
    wnd->next = window_list;
    wnd->prev = 0;
    if (window_list) window_list->prev = wnd;
    window_list = wnd;
    window_count++;

    activate_window(wnd);
    return wnd;
}

/* ============================================================================
 * Destroy Window
 * ============================================================================ */
void destroy_window(window_t* w) {
    if (!w) return;

    if (w->on_close) w->on_close(w);

    if (w->prev) w->prev->next = w->next;
    if (w->next) w->next->prev = w->prev;
    if (window_list == w) window_list = w->next;
    if (active_window == w) active_window = w->next ? w->next : window_list;

    if (w->content) kfree(w->content);
    kfree(w);
    window_count--;
}

/* ============================================================================
 * Show/Hide Window
 * ============================================================================ */
void show_window(window_t* w) {
    if (w) w->flags |= WF_VISIBLE;
}

void hide_window(window_t* w) {
    if (w) w->flags &= ~WF_VISIBLE;
}

/* ============================================================================
 * Activate Window
 * ============================================================================ */
void activate_window(window_t* w) {
    if (!w || !(w->flags & WF_VISIBLE)) return;

    /* Deactivate current */
    if (active_window) {
        active_window->flags &= ~WF_ACTIVE;
    }

    /* Move to front */
    if (w->prev) w->prev->next = w->next;
    if (w->next) w->next->prev = w->prev;
    if (window_list == w) window_list = w->next;

    w->next = window_list;
    w->prev = 0;
    if (window_list) window_list->prev = w;
    window_list = w;

    w->flags |= WF_ACTIVE;
    active_window = w;
}

/* ============================================================================
 * Move/Resize Window
 * ============================================================================ */
void move_window(window_t* w, int x, int y) {
    if (!w || !(w->flags & WF_MOVABLE)) return;
    w->x = x;
    w->y = y;

    /* Clamp to screen */
    if (w->x < 0) w->x = 0;
    if (w->y < 0) w->y = 0;
    if (w->x + w->width > SCREEN_WIDTH) w->x = SCREEN_WIDTH - w->width;
    if (w->y + w->height > SCREEN_HEIGHT) w->y = SCREEN_HEIGHT - w->height;
}

void resize_window(window_t* w, int width, int height) {
    if (!w || !(w->flags & WF_RESIZABLE)) return;
    w->width = (width < WINDOW_MIN_W) ? WINDOW_MIN_W : width;
    w->height = (height < WINDOW_MIN_H) ? WINDOW_MIN_H : height;

    /* Reallocate content buffer */
    w->content_w = w->width - WINDOW_BORDER * 2;
    w->content_h = w->height - WINDOW_TITLE_H - WINDOW_BORDER * 2;
}

/* ============================================================================
 * Minimize/Maximize/Restore
 * ============================================================================ */
void minimize_window(window_t* w) {
    if (!w) return;
    w->flags |= WF_MINIMIZED;
    w->flags &= ~WF_VISIBLE;
}

void maximize_window(window_t* w) {
    if (!w || (w->flags & WF_MAXIMIZED)) return;
    w->prev_x = w->x;
    w->prev_y = w->y;
    w->prev_w = w->width;
    w->prev_h = w->height;
    w->x = 0;
    w->y = 0;
    w->width = SCREEN_WIDTH;
    w->height = SCREEN_HEIGHT;
    w->flags |= WF_MAXIMIZED;
}

void restore_window(window_t* w) {
    if (!w || !(w->flags & WF_MAXIMIZED)) return;
    w->x = w->prev_x;
    w->y = w->prev_y;
    w->width = w->prev_w;
    w->height = w->prev_h;
    w->flags &= ~WF_MAXIMIZED;
}

/* ============================================================================
 * Paint Window
 * ============================================================================ */
void paint_window(window_t* w) {
    if (!w || !(w->flags & WF_VISIBLE)) return;

    /* Draw shadow */
    if (w->flags & WF_HAS_SHADOW) {
        draw_window_shadow(w);
    }

    /* Draw border */
    draw_window_border(w);

    /* Draw title bar */
    draw_window_titlebar(w);

    /* Draw content */
    if (w->on_paint) {
        w->on_paint(w);
    } else {
        /* Default content */
        draw_rect(w->x + WINDOW_BORDER, w->y + WINDOW_TITLE_H,
                  w->width - WINDOW_BORDER * 2,
                  w->height - WINDOW_TITLE_H - WINDOW_BORDER,
                  w->bg_color);
    }

    /* Draw buttons */
    draw_window_buttons(w);
}

/* ============================================================================
 * Paint All Windows
 * ============================================================================ */
void paint_all_windows(void) {
    /* Paint from bottom to top */
    window_t* w = window_list;
    while (w && w->next) w = w->next;

    while (w) {
        paint_window(w);
        w = w->prev;
    }
}

/* ============================================================================
 * Window Decorations
 * ============================================================================ */
void draw_window_shadow(window_t* w) {
    /* Soft shadow */
    for (int i = 0; i < 6; i++) {
        uint8_t alpha = 30 - i * 5;
        draw_rect(w->x + w->width + i, w->y + i, 1, w->height, rgb(0, 0, 0));
        draw_rect(w->x + i, w->y + w->height + i, w->width + 6 - i, 1, rgb(0, 0, 0));
    }
}

void draw_window_border(window_t* w) {
    uint32_t border_color = (w->flags & WF_ACTIVE) ? rgb(80, 140, 220) : rgb(160, 160, 170);
    draw_rect_outline(w->x, w->y, w->width, w->height, border_color, WINDOW_BORDER);
}

void draw_window_titlebar(window_t* w) {
    uint32_t top_color = (w->flags & WF_ACTIVE) ? rgb(70, 130, 210) : rgb(180, 180, 190);
    uint32_t bottom_color = (w->flags & WF_ACTIVE) ? rgb(50, 100, 180) : rgb(160, 160, 170);

    draw_gradient_v(w->x + WINDOW_BORDER, w->y + WINDOW_BORDER,
                    w->width - WINDOW_BORDER * 2, WINDOW_TITLE_H - WINDOW_BORDER,
                    top_color, bottom_color);

    /* Title text */
    draw_string(w->x + 10, w->y + 5, w->title, COLOR_WHITE, 1);
}

void draw_window_buttons(window_t* w) {
    if (!(w->flags & WF_CLOSEABLE)) return;

    int bx = w->x + w->width - 22;
    int by = w->y + 4;

    /* Close button */
    draw_circle_filled(bx + 8, by + 8, 7, rgb(220, 80, 80));
    draw_line(bx + 4, by + 4, bx + 12, by + 12, COLOR_WHITE, 1);
    draw_line(bx + 12, by + 4, bx + 4, by + 12, COLOR_WHITE, 1);

    /* Minimize button */
    if (w->flags & WF_RESIZABLE) {
        bx -= 22;
        draw_circle_filled(bx + 8, by + 8, 7, rgb(220, 180, 60));
        draw_rect(bx + 4, by + 11, 8, 2, COLOR_WHITE);
    }

    /* Maximize button */
    if (w->flags & WF_RESIZABLE) {
        bx -= 22;
        draw_circle_filled(bx + 8, by + 8, 7, rgb(80, 180, 80));
        draw_rect_outline(bx + 4, by + 4, 8, 8, COLOR_WHITE, 1);
    }
}

/* ============================================================================
 * Hit Testing
 * ============================================================================ */
window_t* window_at(int x, int y) {
    window_t* w = window_list;
    while (w) {
        if ((w->flags & WF_VISIBLE) &&
            x >= w->x && x < w->x + w->width &&
            y >= w->y && y < w->y + w->height) {
            return w;
        }
        w = w->next;
    }
    return 0;
}

int window_hit_test(window_t* w, int x, int y) {
    if (!w) return HT_NONE;

    int local_x = x - w->x;
    int local_y = y - w->y;

    /* Close button */
    if (w->flags & WF_CLOSEABLE) {
        int bx = w->width - 22;
        int by = 4;
        if (local_x >= bx && local_x < bx + 16 && local_y >= by && local_y < by + 16) {
            return HT_CLOSE;
        }
    }

    /* Minimize button */
    if (w->flags & WF_RESIZABLE) {
        int bx = w->width - 44;
        int by = 4;
        if (local_x >= bx && local_x < bx + 16 && local_y >= by && local_y < by + 16) {
            return HT_MINIMIZE;
        }
    }

    /* Maximize button */
    if (w->flags & WF_RESIZABLE) {
        int bx = w->width - 66;
        int by = 4;
        if (local_x >= bx && local_x < bx + 16 && local_y >= by && local_y < by + 16) {
            return HT_MAXIMIZE;
        }
    }

    /* Title bar */
    if (local_y < WINDOW_TITLE_H) {
        return HT_TITLEBAR;
    }

    /* Border */
    if (local_x < WINDOW_BORDER || local_x >= w->width - WINDOW_BORDER ||
        local_y < WINDOW_BORDER || local_y >= w->height - WINDOW_BORDER) {
        return HT_BORDER;
    }

    return HT_CLIENT;
}

/* ============================================================================
 * Mouse Cursor
 * ============================================================================ */
void draw_cursor(int x, int y) {
    /* Simple arrow cursor */
    uint32_t color = COLOR_WHITE;
    uint32_t outline = COLOR_BLACK;

    for (int i = 0; i < 12; i++) {
        putpixel(x + i, y + i, outline);
        putpixel(x + i + 1, y + i, color);
    }
    for (int i = 0; i < 8; i++) {
        putpixel(x + i, y + 12 - i, outline);
        putpixel(x + i + 1, y + 12 - i, color);
    }
}

void erase_cursor(int x, int y) {
    /* Will be handled by desktop redraw */
}

/* ============================================================================
 * Update Windows
 * ============================================================================ */
void update_windows(void) {
    /* Mouse cursor update */
    cursor_x = mouse.x;
    cursor_y = mouse.y;
}

/* Simple kmalloc/kfree stubs */
static uint8_t heap[0x100000];
static uint32_t heap_ptr = 0;

uint32_t kmalloc(uint32_t sz) {
    uint32_t addr = (uint32_t)(heap + heap_ptr);
    heap_ptr += sz;
    return addr;
}

uint32_t kmalloc_a(uint32_t sz) {
    return kmalloc(sz);
}

void kfree(void* ptr) {
    /* Simple allocator - no free for now */
}
