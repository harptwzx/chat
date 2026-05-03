/* ============================================================================
 * Resurgam OS - Kernel Header
 * ============================================================================ */

#ifndef KERNEL_H
#define KERNEL_H

/* ============================================================================
 * Basic Types
 * ============================================================================ */
typedef unsigned char   uint8_t;
typedef unsigned short  uint16_t;
typedef unsigned int    uint32_t;
typedef unsigned long long uint64_t;
typedef signed char     int8_t;
typedef signed short    int16_t;
typedef signed int      int32_t;
typedef signed long long int64_t;
typedef uint32_t        size_t;
typedef uint32_t        uintptr_t;
typedef uint8_t         bool;
#define true  1
#define false 0
#define NULL  ((void*)0)

/* ============================================================================
 * Screen Constants
 * ============================================================================ */
#define SCREEN_WIDTH    640
#define SCREEN_HEIGHT   480
#define SCREEN_BPP      32
#define VGA_ADDR        0xFD000000

/* ============================================================================
 * Colors (RGB)
 * ============================================================================ */
#define COLOR_BLACK     0x000000
#define COLOR_WHITE     0xFFFFFF
#define COLOR_RED       0xFF4444
#define COLOR_GREEN     0x44FF44
#define COLOR_BLUE      0x4444FF
#define COLOR_YELLOW    0xFFFF44
#define COLOR_CYAN      0x44FFFF
#define COLOR_MAGENTA   0xFF44FF
#define COLOR_GRAY      0x888888
#define COLOR_DARKGRAY  0x444444
#define COLOR_ORANGE    0xFF8844
#define COLOR_PURPLE    0x8844FF
#define COLOR_TEAL      0x44FFAA

/* ============================================================================
 * Inline Assembly Helpers
 * ============================================================================ */
static inline uint8_t inb(uint16_t port) {
    uint8_t result;
    asm volatile("inb %1, %0" : "=a"(result) : "Nd"(port));
    return result;
}

static inline void outb(uint16_t port, uint8_t data) {
    asm volatile("outb %0, %1" : : "a"(data), "Nd"(port));
}

static inline void io_wait(void) {
    asm volatile("jmp 1f
	1: jmp 1f
	1:");
}

static inline uint32_t read_cr0(void) {
    uint32_t val;
    asm volatile("mov %%cr0, %0" : "=r"(val));
    return val;
}

static inline uint32_t read_cr3(void) {
    uint32_t val;
    asm volatile("mov %%cr3, %0" : "=r"(val));
    return val;
}

static inline void write_cr3(uint32_t val) {
    asm volatile("mov %0, %%cr3" : : "r"(val));
}

static inline void sti(void) {
    asm volatile("sti");
}

static inline void cli(void) {
    asm volatile("cli");
}

static inline void halt(void) {
    asm volatile("hlt");
}

/* ============================================================================
 * Utility Functions
 * ============================================================================ */
static inline uint32_t rgb(uint8_t r, uint8_t g, uint8_t b) {
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

static inline uint32_t min(uint32_t a, uint32_t b) {
    return (a < b) ? a : b;
}

static inline uint32_t max(uint32_t a, uint32_t b) {
    return (a > b) ? a : b;
}

/* ============================================================================
 * Memory Functions
 * ============================================================================ */
static inline void* memset(void* dest, int val, size_t count) {
    uint8_t* d = dest;
    while (count--) *d++ = val;
    return dest;
}

static inline void* memcpy(void* dest, const void* src, size_t count) {
    uint8_t* d = dest;
    const uint8_t* s = src;
    while (count--) *d++ = *s++;
    return dest;
}

static inline int memcmp(const void* s1, const void* s2, size_t n) {
    const uint8_t* p1 = s1;
    const uint8_t* p2 = s2;
    while (n--) {
        if (*p1 != *p2) return *p1 - *p2;
        p1++; p2++;
    }
    return 0;
}

static inline size_t strlen(const char* str) {
    size_t len = 0;
    while (str[len]) len++;
    return len;
}

static inline int strcmp(const char* s1, const char* s2) {
    while (*s1 && *s1 == *s2) { s1++; s2++; }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

static inline int strncmp(const char* s1, const char* s2, size_t n) {
    while (n && *s1 && *s1 == *s2) { s1++; s2++; n--; }
    return n ? (*(unsigned char*)s1 - *(unsigned char*)s2) : 0;
}

static inline char* strcpy(char* dest, const char* src) {
    char* d = dest;
    while ((*d++ = *src++));
    return dest;
}

static inline char* strncpy(char* dest, const char* src, size_t n) {
    char* d = dest;
    while (n-- && (*d++ = *src++));
    return dest;
}

static inline int atoi(const char* str) {
    int result = 0;
    int sign = 1;
    if (*str == '-') { sign = -1; str++; }
    while (*str >= '0' && *str <= '9') {
        result = result * 10 + (*str - '0');
        str++;
    }
    return result * sign;
}

static inline char* itoa(int value, char* str, int base) {
    char* rc = str;
    char* ptr = str;
    char* low = str;

    if (base < 2 || base > 36) {
        *str = 0;
        return str;
    }

    if (value < 0 && base == 10) *ptr++ = '-';

    do {
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz"[35 + value % base];
        value /= base;
    } while (value);

    *ptr-- = 0;

    while (low < ptr) {
        char tmp = *low;
        *low++ = *ptr;
        *ptr-- = tmp;
    }

    return rc;
}

/* ============================================================================
 * Simple sprintf
 * ============================================================================ */
static inline int sprintf(char* buf, const char* fmt, ...) {
    /* Very simple sprintf - just copy format string for now */
    strcpy(buf, fmt);
    return strlen(buf);
}

/* ============================================================================
 * abs function
 * ============================================================================ */
static inline int abs(int x) {
    return (x < 0) ? -x : x;
}

/* ============================================================================
 * sqrt approximation (integer)
 * ============================================================================ */
static inline int sqrt(int x) {
    if (x < 0) return 0;
    int r = x;
    while (r * r > x) r = (r + x / r) / 2;
    return r;
}

/* ============================================================================
 * kmalloc/kfree stubs (defined in window.c)
 * ============================================================================ */
extern uint32_t kmalloc(uint32_t sz);
extern uint32_t kmalloc_a(uint32_t sz);
extern void kfree(void* ptr);

/* ============================================================================
 * Forward declarations for types used in headers
 * ============================================================================ */
struct window;
typedef struct window window_t;

struct desktop_icon;
typedef struct desktop_icon desktop_icon_t;

struct taskbar_button;
typedef struct taskbar_button taskbar_button_t;

struct mouse_state;

/* ============================================================================
 * Kernel Function Declarations
 * ============================================================================ */
void kernel_main(void);
void main_loop(void);
void show_boot_screen(void);
void draw_logo(int x, int y);
void init_serial(void);
void serial_putc(char c);
void kprintf(const char* fmt, ...);

/* External assembly functions */
extern void load_gdt(void* gdtr);
extern void load_idt(void* idtr);
extern void enable_fpu(void);
extern void halt_cpu(void);
extern uint32_t get_esp(void);
extern uint32_t get_ebp(void);
extern uint32_t get_eflags(void);

/* Timer */
void init_timer(uint32_t frequency);
void timer_handler(void);
void sleep(uint32_t ms);
void delay(uint32_t ms);

/* Keyboard */
void init_keyboard(void);
void keyboard_handler(void);
void process_keyboard(void);

/* Mouse */
void init_mouse(void);
void mouse_handler(void);
void process_mouse(void);
void handle_mouse_click(int x, int y, int button);
void handle_mouse_release(int x, int y, int button);
void handle_mouse_move(int x, int y);

/* GDT/IDT */
void init_gdt(void);
void init_idt(void);
void remap_pic(void);
void pic_send_eoi(int irq);
void pic_mask_irq(int irq);
void pic_unmask_irq(int irq);

/* Paging */
void init_paging(void);

/* Task */
void init_tasking(void);

/* VFS */
void init_vfs(void);

/* Shell */
void init_shell(void);
void shell_create_window(void);
void shell_input(char c);
void shell_arrow_key(uint8_t scancode);
void shell_execute(void);
void shell_print(const char* str);
void shell_println(const char* str);
void shell_clear(void);
void shell_prompt(void);
void shell_scroll(void);
void paint_shell_window(window_t* w);
void shell_window_key(window_t* w, char key);

/* Window Manager */
void init_window_manager(void);
window_t* create_window(const char* title, int x, int y, int w, int h, uint32_t flags);
void destroy_window(window_t* w);
void show_window(window_t* w);
void hide_window(window_t* w);
void activate_window(window_t* w);
void move_window(window_t* w, int x, int y);
void resize_window(window_t* w, int width, int height);
void minimize_window(window_t* w);
void maximize_window(window_t* w);
void restore_window(window_t* w);
void paint_window(window_t* w);
void paint_all_windows(void);
void update_windows(void);
void draw_window_frame(window_t* w);
void draw_window_titlebar(window_t* w);
void draw_window_buttons(window_t* w);
void draw_window_border(window_t* w);
void draw_window_shadow(window_t* w);
void draw_cursor(int x, int y);
void erase_cursor(int x, int y);
window_t* window_at(int x, int y);
int window_hit_test(window_t* w, int x, int y);

/* Desktop */
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

/* VGA */
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

/* Console */
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

/* Window constants */
#define WINDOW_TITLE_H  24
#define WINDOW_BORDER   2

/* Window flags */
#define WF_VISIBLE      0x01
#define WF_ACTIVE       0x02
#define WF_MINIMIZED    0x04
#define WF_MAXIMIZED    0x08
#define WF_RESIZABLE    0x10
#define WF_MOVABLE      0x20
#define WF_CLOSEABLE    0x40
#define WF_HAS_SHADOW   0x80

/* Mouse button states */
#define MOUSE_LEFT      0x01
#define MOUSE_RIGHT     0x02
#define MOUSE_MIDDLE    0x04

/* Drag state (defined in window.c) */
extern window_t* drag_window;
extern int drag_offset_x;
extern int drag_offset_y;
extern int drag_mode;

/* Hit test results */
#define HT_CLIENT       0
#define HT_TITLEBAR     1
#define HT_CLOSE        2
#define HT_MINIMIZE     3
#define HT_MAXIMIZE     4
#define HT_BORDER       5
#define HT_NONE         6

/* Framebuffer (defined in vga.c) */
extern uint32_t* framebuffer;
extern int clip_x1, clip_y1, clip_x2, clip_y2;

/* Taskbar */
#define TASKBAR_HEIGHT  28

/* Timer vars (defined in timer.c) */
extern volatile uint32_t timer_ticks;
extern volatile uint32_t timer_seconds;
extern volatile uint32_t timer_frequency;

#endif
