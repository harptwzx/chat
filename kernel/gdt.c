/* ============================================================================
 * Resurgam OS - Global Descriptor Table
 * ============================================================================ */

#include "kernel.h"
#include "gdt.h"

/* GDT entries */
static gdt_entry_t gdt[GDT_ENTRIES];
static gdt_register_t gdtr;
static tss_entry_t tss;

/* ============================================================================
 * Initialize GDT
 * ============================================================================ */
void init_gdt(void) {
    /* Null descriptor */
    gdt_set_gate(0, 0, 0, 0, 0);

    /* Kernel code segment */
    gdt_set_gate(1, 0, 0xFFFFFFFF, 0x9A, 0xCF);

    /* Kernel data segment */
    gdt_set_gate(2, 0, 0xFFFFFFFF, 0x92, 0xCF);

    /* User code segment */
    gdt_set_gate(3, 0, 0xFFFFFFFF, 0xFA, 0xCF);

    /* User data segment */
    gdt_set_gate(4, 0, 0xFFFFFFFF, 0xF2, 0xCF);

    /* TSS */
    tss_set_gate(5, KERNEL_DATA_SEG, 0x90000);

    /* Load GDT */
    gdtr.limit = sizeof(gdt) - 1;
    gdtr.base = (uint32_t)&gdt;
    load_gdt(&gdtr);

    /* Flush TSS */
    tss_flush();
}

/* ============================================================================
 * Set GDT Gate
 * ============================================================================ */
void gdt_set_gate(int num, uint32_t base, uint32_t limit, uint8_t access, uint8_t gran) {
    gdt[num].base_low = base & 0xFFFF;
    gdt[num].base_middle = (base >> 16) & 0xFF;
    gdt[num].base_high = (base >> 24) & 0xFF;
    gdt[num].limit_low = limit & 0xFFFF;
    gdt[num].granularity = (limit >> 16) & 0x0F;
    gdt[num].granularity |= gran & 0xF0;
    gdt[num].access = access;
}

/* ============================================================================
 * Set TSS Gate
 * ============================================================================ */
void tss_set_gate(int num, uint16_t ss0, uint32_t esp0) {
    uint32_t base = (uint32_t)&tss;
    uint32_t limit = sizeof(tss) - 1;

    gdt_set_gate(num, base, limit, 0x89, 0x40);

    memset(&tss, 0, sizeof(tss));
    tss.ss0 = ss0;
    tss.esp0 = esp0;
    tss.cs = 0x0B;      /* User code segment with RPL=3 */
    tss.ss = 0x13;      /* User data segment with RPL=3 */
    tss.ds = 0x13;
    tss.es = 0x13;
    tss.fs = 0x13;
    tss.gs = 0x13;
    tss.iomap_base = sizeof(tss);
}

/* ============================================================================
 * Flush TSS (assembly)
 * ============================================================================ */
void tss_flush(void) {
    asm volatile("ltr %%ax" : : "a"(TSS_SEG));
}
