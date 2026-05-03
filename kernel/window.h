/* ============================================================================
 * Resurgam OS - Window Manager Header
 * ============================================================================ */

#ifndef WINDOW_H
#define WINDOW_H

#include "kernel.h"

#define MAX_WINDOWS     32
#define WINDOW_TITLE_H  24
#define WINDOW_BORDER   2
#define WINDOW_MIN_W    120
#define WINDOW_MIN_H    80

/* Window flags */
#define WF_VISIBLE      0x01
#define WF_ACTIVE       0x02
#define WF_MINIMIZED    0x04
#define WF_MAXIMIZED    0x08
#define WF_RESIZABLE    0x10
#define WF_MOVABLE      0x20
#define WF_CLOSEABLE    0x40
#define WF_HAS_SHADOW   0x80

/* Window structure */
typedef struct window {
    int id;
    int x, y;
    int width, height;
    int prev_x, prev_y;
    int prev_w, prev_h;
    char title[64];
    uint32_t flags;
    uint32_t bg_color;
    uint32_t title_color;

    /* Content buffer */
    uint32_t* content;
    int content_w, content_h;

    /* Event handlers */
    void (*on_paint)(struct window* w);
    void (*on_click)(struct window* w, int x, int y, int button);
    void (*on_key)(struct window* w, char key);
    void (*on_close)(struct window* w);

    struct window* next;
    struct window* prev;
} window_t;

/* Window manager state */
extern window_t* window_list;
extern window_t* active_window;
extern int window_count;
extern int next_window_id;

/* Mouse cursor */
extern int cursor_x, cursor_y;
extern uint32_t cursor_color;

/* Functions */
void init_window_manager(void);
window_t* create_window(const char* title, int x, int y, int w, int h, uint32_t flags);
void destroy_window(window_t* w);
void show_window(window_t* w);
void hide_window(window_t* w);
void activate_window(window_t* w);
void move_window(window_t* w, int x, int y);
void resize_window(window_t* w, int w, int h);
void minimize_window(window_t* w);
void maximize_window(window_t* w);
void restore_window(window_t* w);
void paint_window(window_t* w);
void paint_all_windows(void);
void update_windows(void);

/* Window decorations */
void draw_window_frame(window_t* w);
void draw_window_titlebar(window_t* w);
void draw_window_buttons(window_t* w);
void draw_window_border(window_t* w);
void draw_window_shadow(window_t* w);

/* Mouse cursor */
void draw_cursor(int x, int y);
void erase_cursor(int x, int y);

/* Hit testing */
window_t* window_at(int x, int y);
int window_hit_test(window_t* w, int x, int y);
#define HT_CLIENT       0
#define HT_TITLEBAR     1
#define HT_CLOSE        2
#define HT_MINIMIZE     3
#define HT_MAXIMIZE     4
#define HT_BORDER       5
#define HT_NONE         6

#endif
