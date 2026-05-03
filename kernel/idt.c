/* ============================================================================
 * Resurgam OS - Interrupt Descriptor Table
 * ============================================================================ */

#include "kernel.h"
#include "idt.h"

/* IDT entries */
static idt_entry_t idt[IDT_ENTRIES];
static idt_register_t idtr;

/* IRQ handler table */
static irq_handler_t irq_handlers[16] = {0};

/* External ISR table from assembly */
extern uint32_t isr_table[];

/* ============================================================================
 * Initialize IDT
 * ============================================================================ */
void init_idt(void) {
    /* Clear IDT */
    for (int i = 0; i < IDT_ENTRIES; i++) {
        idt_set_gate(i, 0, 0, 0);
    }

    /* Remap PIC */
    remap_pic();

    /* Set up ISR gates (0x8E = present, ring 0, 32-bit interrupt gate) */
    for (int i = 0; i < 48; i++) {
        idt_set_gate(i, isr_table[i], 0x08, 0x8E);
    }

    /* Set up syscall gate (int 0x80) - allow ring 3 access */
    idt_set_gate(0x80, (uint32_t)syscall_entry, 0x08, 0xEE);

    /* Load IDT */
    idtr.limit = sizeof(idt) - 1;
    idtr.base = (uint32_t)&idt;
    load_idt(&idtr);

    /* Unmask important IRQs */
    pic_unmask_irq(0);  /* Timer */
    pic_unmask_irq(1);  /* Keyboard */
    pic_unmask_irq(2);  /* Cascade */
    pic_unmask_irq(12); /* Mouse */
}

/* ============================================================================
 * Set IDT Gate
 * ============================================================================ */
void idt_set_gate(int num, uint32_t base, uint16_t selector, uint8_t flags) {
    idt[num].offset_low = base & 0xFFFF;
    idt[num].offset_high = (base >> 16) & 0xFFFF;
    idt[num].selector = selector;
    idt[num].zero = 0;
    idt[num].type_attr = flags;
}

/* ============================================================================
 * Remap PIC (Programmable Interrupt Controller)
 * ============================================================================ */
void remap_pic(void) {
    /* ICW1 */
    outb(0x20, 0x11);
    outb(0xA0, 0x11);

    /* ICW2 - Vector offsets */
    outb(0x21, 0x20); /* Master: 0x20-0x27 (32-39) */
    outb(0xA1, 0x28); /* Slave: 0x28-0x2F (40-47) */

    /* ICW3 - Cascade */
    outb(0x21, 0x04);
    outb(0xA1, 0x02);

    /* ICW4 */
    outb(0x21, 0x01);
    outb(0xA1, 0x01);

    /* Mask all interrupts initially */
    outb(0x21, 0xFF);
    outb(0xA1, 0xFF);
}

/* ============================================================================
 * PIC Operations
 * ============================================================================ */
void pic_send_eoi(int irq) {
    if (irq >= 8) {
        outb(0xA0, 0x20);
    }
    outb(0x20, 0x20);
}

void pic_mask_irq(int irq) {
    uint16_t port = (irq < 8) ? 0x21 : 0xA1;
    outb(port, inb(port) | (1 << (irq % 8)));
}

void pic_unmask_irq(int irq) {
    uint16_t port = (irq < 8) ? 0x21 : 0xA1;
    outb(port, inb(port) & ~(1 << (irq % 8)));
}

/* ============================================================================
 * Register IRQ Handler
 * ============================================================================ */
void register_irq_handler(int irq, irq_handler_t handler) {
    if (irq >= 0 && irq < 16) {
        irq_handlers[irq] = handler;
    }
}
