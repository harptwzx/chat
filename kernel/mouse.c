/* ============================================================================
 * Resurgam OS - PS/2 Mouse Driver
 * Supports standard 3-button mouse with scroll wheel
 * ============================================================================ */

#include "kernel.h"
#include "mouse.h"
#include "window.h"
#include "desktop.h"

/* Mouse state */
mouse_state_t mouse = {0, 0, 0, 0, 0};
volatile int mouse_packet_ready = 0;

/* Packet buffer */
static uint8_t mouse_packet[4];
static int mouse_cycle = 0;
static int mouse_initialized = 0;

/* ============================================================================
 * Initialize Mouse
 * ============================================================================ */
void init_mouse(void) {
    uint8_t status;

    /* Enable mouse auxiliary device */
    mouse_wait(1);
    outb(MOUSE_CMD_PORT, 0xA8);

    /* Enable interrupts */
    mouse_wait(1);
    outb(MOUSE_CMD_PORT, 0x20);
    mouse_wait(0);
    status = (inb(MOUSE_DATA_PORT) | 2);
    mouse_wait(1);
    outb(MOUSE_CMD_PORT, 0x60);
    mouse_wait(1);
    outb(MOUSE_DATA_PORT, status);

    /* Tell mouse to use default settings */
    mouse_write(0xF6);
    mouse_read();

    /* Enable mouse */
    mouse_write(0xF4);
    mouse_read();

    /* Try to enable scroll wheel (Intellimouse) */
    mouse_write(0xF3);
    mouse_read();
    mouse_write(200);
    mouse_read();
    mouse_write(0xF3);
    mouse_read();
    mouse_write(100);
    mouse_read();
    mouse_write(0xF3);
    mouse_read();
    mouse_write(80);
    mouse_read();

    /* Get mouse ID */
    mouse_write(0xF2);
    mouse_read();
    uint8_t id = mouse_read();

    mouse_initialized = 1;
    mouse.present = 1;

    /* Center mouse on screen */
    mouse.x = SCREEN_WIDTH / 2;
    mouse.y = SCREEN_HEIGHT / 2;
}

/* ============================================================================
 * Mouse Wait
 * ============================================================================ */
void mouse_wait(uint8_t type) {
    uint32_t timeout = 100000;
    if (type == 0) {
        /* Wait for data */
        while (timeout--) {
            if ((inb(MOUSE_STATUS_PORT) & 1) == 1) return;
        }
    } else {
        /* Wait for signal */
        while (timeout--) {
            if ((inb(MOUSE_STATUS_PORT) & 2) == 0) return;
        }
    }
}

/* ============================================================================
 * Mouse Write
 * ============================================================================ */
void mouse_write(uint8_t data) {
    mouse_wait(1);
    outb(MOUSE_CMD_PORT, 0xD4);
    mouse_wait(1);
    outb(MOUSE_DATA_PORT, data);
}

/* ============================================================================
 * Mouse Read
 * ============================================================================ */
uint8_t mouse_read(void) {
    mouse_wait(0);
    return inb(MOUSE_DATA_PORT);
}

/* ============================================================================
 * Mouse Interrupt Handler
 * ============================================================================ */
void mouse_handler(void) {
    if (!mouse_initialized) return;

    uint8_t data = inb(MOUSE_DATA_PORT);

    /* Process packet */
    switch (mouse_cycle) {
        case 0:
            if ((data & 0x08) == 0) return; /* Invalid packet */
            mouse_packet[0] = data;
            mouse_cycle++;
            break;
        case 1:
            mouse_packet[1] = data;
            mouse_cycle++;
            break;
        case 2:
            mouse_packet[2] = data;
            mouse_cycle = 0;
            mouse_packet_ready = 1;
            break;
    }
}

/* ============================================================================
 * Process Mouse Packet
 * ============================================================================ */
void process_mouse(void) {
    if (!mouse_packet_ready) return;
    mouse_packet_ready = 0;

    uint8_t flags = mouse_packet[0];
    int8_t dx = (int8_t)mouse_packet[1];
    int8_t dy = (int8_t)mouse_packet[2];

    /* Update button states */
    int old_buttons = mouse.buttons;
    mouse.buttons = flags & 0x07;

    /* Update position */
    mouse.x += dx;
    mouse.y -= dy; /* Y is inverted */

    /* Clamp to screen */
    if (mouse.x < 0) mouse.x = 0;
    if (mouse.x >= SCREEN_WIDTH) mouse.x = SCREEN_WIDTH - 1;
    if (mouse.y < 0) mouse.y = 0;
    if (mouse.y >= SCREEN_HEIGHT) mouse.y = SCREEN_HEIGHT - 1;

    /* Handle button events */
    if ((mouse.buttons & MOUSE_LEFT) && !(old_buttons & MOUSE_LEFT)) {
        /* Left button pressed */
        handle_mouse_click(mouse.x, mouse.y, MOUSE_LEFT);
    }
    if (!(mouse.buttons & MOUSE_LEFT) && (old_buttons & MOUSE_LEFT)) {
        /* Left button released */
        handle_mouse_release(mouse.x, mouse.y, MOUSE_LEFT);
    }
    if ((mouse.buttons & MOUSE_RIGHT) && !(old_buttons & MOUSE_RIGHT)) {
        /* Right button pressed */
        handle_mouse_click(mouse.x, mouse.y, MOUSE_RIGHT);
    }
    if ((mouse.buttons & MOUSE_MIDDLE) && !(old_buttons & MOUSE_MIDDLE)) {
        /* Middle button pressed */
        handle_mouse_click(mouse.x, mouse.y, MOUSE_MIDDLE);
    }

    /* Handle mouse movement */
    if (dx != 0 || dy != 0) {
        handle_mouse_move(mouse.x, mouse.y);
    }
}
