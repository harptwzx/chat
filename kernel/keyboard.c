/* ============================================================================
 * Resurgam OS - PS/2 Keyboard Driver
 * ============================================================================ */

#include "kernel.h"
#include "keyboard.h"
#include "console.h"
#include "shell.h"

/* Keyboard scan code to ASCII mapping */
static const char scancode_to_ascii[] = {
    0,   0,   '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0,   0,
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0,   0,   'a', 's',
    'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', ''', '`', 0,   '\', 'z', 'x', 'c', 'v',
    'b', 'n', 'm', ',', '.', '/', 0,   '*', 0,   ' ', 0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
};

static const char scancode_to_ascii_shift[] = {
    0,   0,   '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0,   0,
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0,   0,   'A', 'S',
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~', 0,   '|', 'Z', 'X', 'C', 'V',
    'B', 'N', 'M', '<', '>', '?', 0,   '*', 0,   ' ', 0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
    0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
};

/* Modifier states */
volatile int key_shift = 0;
volatile int key_ctrl = 0;
volatile int key_alt = 0;
volatile int key_caps = 0;

/* Key buffer */
volatile char key_buffer[KEY_BUFFER_SIZE];
volatile int key_buffer_head = 0;
volatile int key_buffer_tail = 0;
volatile int key_buffer_count = 0;

/* ============================================================================
 * Initialize Keyboard
 * ============================================================================ */
void init_keyboard(void) {
    /* Wait for keyboard controller */
    while (inb(KEYBOARD_STATUS_PORT) & 0x02);

    /* Enable keyboard */
    outb(KEYBOARD_CMD_PORT, 0xAE);

    /* Read configuration byte */
    outb(KEYBOARD_CMD_PORT, 0x20);
    while (!(inb(KEYBOARD_STATUS_PORT) & 0x01));
    uint8_t config = inb(KEYBOARD_DATA_PORT);

    /* Enable IRQ1 */
    config |= 0x01;

    /* Write configuration byte */
    outb(KEYBOARD_CMD_PORT, 0x60);
    while (inb(KEYBOARD_STATUS_PORT) & 0x02);
    outb(KEYBOARD_DATA_PORT, config);

    /* Reset keyboard */
    outb(KEYBOARD_DATA_PORT, 0xFF);
    while (!(inb(KEYBOARD_STATUS_PORT) & 0x01));
    inb(KEYBOARD_DATA_PORT); /* Ack */
}

/* ============================================================================
 * Keyboard Interrupt Handler
 * ============================================================================ */
void keyboard_handler(void) {
    uint8_t scancode = inb(KEYBOARD_DATA_PORT);

    /* Check for break code (key release) */
    if (scancode & 0x80) {
        scancode &= 0x7F;
        switch (scancode) {
            case KEY_LSHIFT:
            case KEY_RSHIFT:
                key_shift = 0;
                break;
            case KEY_LCTRL:
                key_ctrl = 0;
                break;
            case KEY_LALT:
                key_alt = 0;
                break;
        }
        return;
    }

    /* Handle make code (key press) */
    switch (scancode) {
        case KEY_LSHIFT:
        case KEY_RSHIFT:
            key_shift = 1;
            return;
        case KEY_LCTRL:
            key_ctrl = 1;
            return;
        case KEY_LALT:
            key_alt = 1;
            return;
        case KEY_CAPS:
            key_caps = !key_caps;
            return;
        case KEY_F1:
        case KEY_F2:
        case KEY_F3:
        case KEY_F4:
        case KEY_F5:
        case KEY_F6:
        case KEY_F7:
        case KEY_F8:
        case KEY_F9:
        case KEY_F10:
        case KEY_F11:
        case KEY_F12:
            /* Handle function keys */
            handle_function_key(scancode);
            return;
        case KEY_UP:
        case KEY_DOWN:
        case KEY_LEFT:
        case KEY_RIGHT:
            /* Arrow keys */
            handle_arrow_key(scancode);
            return;
    }

    /* Convert scancode to ASCII */
    char ascii = 0;
    if (scancode < 128) {
        if (key_shift) {
            ascii = scancode_to_ascii_shift[scancode];
        } else {
            ascii = scancode_to_ascii[scancode];
        }

        /* Handle caps lock for letters */
        if (key_caps && ascii >= 'a' && ascii <= 'z') {
            ascii = ascii - 'a' + 'A';
        } else if (key_caps && ascii >= 'A' && ascii <= 'Z') {
            ascii = ascii - 'A' + 'a';
        }
    }

    if (ascii) {
        /* Add to buffer */
        if (key_buffer_count < KEY_BUFFER_SIZE) {
            key_buffer[key_buffer_tail] = ascii;
            key_buffer_tail = (key_buffer_tail + 1) % KEY_BUFFER_SIZE;
            key_buffer_count++;
        }

        /* Also send to shell */
        shell_input(ascii);
    }
}

/* ============================================================================
 * Get Key from Buffer
 * ============================================================================ */
char get_key(void) {
    if (key_buffer_count == 0) return 0;

    char key = key_buffer[key_buffer_head];
    key_buffer_head = (key_buffer_head + 1) % KEY_BUFFER_SIZE;
    key_buffer_count--;
    return key;
}

int key_available(void) {
    return key_buffer_count > 0;
}

void keyboard_wait(void) {
    while (!key_available()) {
        asm volatile("hlt");
    }
}

/* ============================================================================
 * Get Key Name
 * ============================================================================ */
const char* get_key_name(uint8_t scancode) {
    static const char* names[] = {
        "", "Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace", "Tab",
        "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "Enter", "Ctrl", "A", "S",
        "D", "F", "G", "H", "J", "K", "L", ";", "'", "`", "Shift", "\", "Z", "X", "C", "V",
        "B", "N", "M", ",", ".", "/", "Shift", "*", "Alt", "Space", "Caps", "F1", "F2", "F3", "F4", "F5",
        "F6", "F7", "F8", "F9", "F10", "Num", "Scroll", "Home", "Up", "PgUp", "-", "Left", "Center", "Right", "+", "End",
        "Down", "PgDn", "Ins", "Del", "", "", "", "F11", "F12"
    };
    if (scancode < sizeof(names)/sizeof(names[0])) {
        return names[scancode];
    }
    return "Unknown";
}

/* ============================================================================
 * Handle Special Keys
 * ============================================================================ */
static void handle_function_key(uint8_t scancode) {
    /* F1-F12 shortcuts */
    switch (scancode) {
        case KEY_F1:
            /* Help */
            break;
        case KEY_F2:
            /* Rename/Settings */
            break;
        case KEY_F3:
            /* Search */
            break;
        case KEY_F4:
            /* Close window */
            break;
        case KEY_F5:
            /* Refresh */
            break;
        case KEY_F11:
            /* Fullscreen toggle */
            break;
    }
}

static void handle_arrow_key(uint8_t scancode) {
    /* Arrow key handling for shell cursor movement */
    shell_arrow_key(scancode);
}
