/* ============================================================================
 * Resurgam OS - PIT Timer Driver
 * ============================================================================ */

#include "kernel.h"
#include "timer.h"

volatile uint32_t timer_ticks = 0;
volatile uint32_t timer_seconds = 0;
static uint32_t timer_frequency = 0;

/* ============================================================================
 * Initialize Timer
 * ============================================================================ */
void init_timer(uint32_t frequency) {
    timer_frequency = frequency;

    /* Calculate divisor */
    uint32_t divisor = TIMER_FREQ / frequency;

    /* Set command byte */
    outb(TIMER_CMD, 0x36);

    /* Set divisor */
    outb(TIMER_DATA, divisor & 0xFF);
    outb(TIMER_DATA, (divisor >> 8) & 0xFF);
}

/* ============================================================================
 * Timer Interrupt Handler
 * ============================================================================ */
void timer_handler(void) {
    timer_ticks++;

    if (timer_ticks % timer_frequency == 0) {
        timer_seconds++;
    }

    /* Task switching every 10ms (100Hz) */
    if (timer_ticks % 10 == 0) {
        /* schedule_next_task(); */
    }
}

/* ============================================================================
 * Get Ticks
 * ============================================================================ */
uint32_t get_ticks(void) {
    return timer_ticks;
}

/* ============================================================================
 * Sleep (busy wait)
 * ============================================================================ */
void sleep(uint32_t ms) {
    uint32_t target = timer_ticks + (ms * timer_frequency) / 1000;
    while (timer_ticks < target) {
        asm volatile("hlt");
    }
}

/* ============================================================================
 * Delay (simple loop)
 * ============================================================================ */
void delay(uint32_t ms) {
    for (volatile uint32_t i = 0; i < ms * 10000; i++);
}
