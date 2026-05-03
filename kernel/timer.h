/* ============================================================================
 * Resurgam OS - PIT Timer Header
 * ============================================================================ */

#ifndef TIMER_H
#define TIMER_H

#include "kernel.h"

#define TIMER_FREQ 1193182
#define TIMER_CMD  0x43
#define TIMER_DATA 0x40

/* Timer tick counter */
extern volatile uint32_t timer_ticks;
extern volatile uint32_t timer_seconds;

/* Functions */
void init_timer(uint32_t frequency);
void timer_handler(void);
uint32_t get_ticks(void);
void sleep(uint32_t ms);
void delay(uint32_t ms);

#endif
