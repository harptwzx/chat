/* ============================================================================
 * Resurgam OS - Desktop Environment Header
 * ============================================================================ */

#ifndef DESKTOP_H
#define DESKTOP_H

#include "kernel.h"

#define TASKBAR_HEIGHT  28
#define ICON_SIZE       48
#define ICON_TEXT_H     14

/* Desktop icon */
typedef struct desktop_icon {
    int x, y;
    char label[32];
    uint32_t color;
    void (*on_click)(struct desktop_icon* icon);
    struct desktop_icon* next;
} desktop_icon_t;

/* Taskbar button */
typedef struct taskbar_button {
    int x, y, w, h;
    char label[32];
    window_t* window;
    uint32_t color;
    struct taskbar_button* next;
} taskbar_button_t;

/* Desktop state */
extern desktop_icon_t* desktop_icons;
extern taskbar_button_t* taskbar_buttons;
extern uint32_t desktop_bg_color;
extern int show_taskbar;
extern int show_clock;

/* Functions */
void init_desktop(void);
void draw_desktop(void);
void draw_taskbar(void);
void draw_clock(void);
void draw_desktop_icons(void);
void add_desktop_icon(const char* label, int x, int y, uint32_t color, void (*on_click)(desktop_icon_t*));
void add_taskbar_button(window_t* w);
void remove_taskbar_button(window_t* w);
void update_taskbar(void);
void handle_desktop_click(int x, int y, int button);
void handle_mouse_move(int x, int y);
void handle_mouse_click(int x, int y, int button);
void handle_mouse_release(int x, int y, int button);

#endif
