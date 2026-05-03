/* ============================================================================
 * Resurgam OS - Interrupt Descriptor Table Header
 * ============================================================================ */

#ifndef IDT_H
#define IDT_H

#include "kernel.h"

#define IDT_ENTRIES 256

/* IDT Gate Descriptor */
typedef struct {
    uint16_t offset_low;
    uint16_t selector;
    uint8_t  zero;
    uint8_t  type_attr;
    uint16_t offset_high;
} __attribute__((packed)) idt_entry_t;

/* IDT Register */
typedef struct {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed)) idt_register_t;

/* IRQ handlers */
typedef void (*irq_handler_t)(void);

/* Functions */
void init_idt(void);
void idt_set_gate(int num, uint32_t base, uint16_t selector, uint8_t flags);
void idt_load(idt_register_t* idtr);
void register_irq_handler(int irq, irq_handler_t handler);

/* PIC remapping */
void remap_pic(void);
void pic_send_eoi(int irq);
void pic_mask_irq(int irq);
void pic_unmask_irq(int irq);

#endif
