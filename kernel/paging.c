/* ============================================================================
 * Resurgam OS - Paging Implementation
 * ============================================================================ */

#include "kernel.h"
#include "paging.h"

/* Kernel page directory */
static page_directory_t* kernel_directory = 0;
static page_directory_t* current_directory = 0;

/* Frame bitmap (manage up to 128MB = 32768 frames) */
static uint32_t* frames_bitmap;
static uint32_t nframes;

/* Heap placement address */
extern uint32_t end;
uint32_t placement_address = (uint32_t)&end;

/* ============================================================================
 * Frame Management
 * ============================================================================ */
#define INDEX_FROM_BIT(a)  ((a) / 32)
#define OFFSET_FROM_BIT(a) ((a) % 32)

static void set_frame(uint32_t frame_addr) {
    uint32_t frame = frame_addr / PAGE_SIZE;
    uint32_t idx = INDEX_FROM_BIT(frame);
    uint32_t off = OFFSET_FROM_BIT(frame);
    frames_bitmap[idx] |= (1 << off);
}

static void clear_frame(uint32_t frame_addr) {
    uint32_t frame = frame_addr / PAGE_SIZE;
    uint32_t idx = INDEX_FROM_BIT(frame);
    uint32_t off = OFFSET_FROM_BIT(frame);
    frames_bitmap[idx] &= ~(1 << off);
}

static uint32_t test_frame(uint32_t frame_addr) {
    uint32_t frame = frame_addr / PAGE_SIZE;
    uint32_t idx = INDEX_FROM_BIT(frame);
    uint32_t off = OFFSET_FROM_BIT(frame);
    return (frames_bitmap[idx] & (1 << off));
}

static uint32_t first_frame(void) {
    for (uint32_t i = 0; i < INDEX_FROM_BIT(nframes); i++) {
        if (frames_bitmap[i] != 0xFFFFFFFF) {
            for (uint32_t j = 0; j < 32; j++) {
                if (!(frames_bitmap[i] & (1 << j))) {
                    return i * 32 + j;
                }
            }
        }
    }
    return (uint32_t)-1;
}

/* ============================================================================
 * Allocate/Free Frame
 * ============================================================================ */
void alloc_frame(page_entry_t* page, int is_kernel, int is_writable) {
    if (*page & PAGE_PRESENT) return;

    uint32_t idx = first_frame();
    if (idx == (uint32_t)-1) {
        /* Out of memory */
        return;
    }

    set_frame(idx * PAGE_SIZE);
    *page = (idx * PAGE_SIZE) | PAGE_PRESENT | (is_writable ? PAGE_WRITABLE : 0) | (is_kernel ? 0 : PAGE_USER);
}

void free_frame(page_entry_t* page) {
    uint32_t frame = *page & PAGE_FRAME;
    if (!frame) return;

    clear_frame(frame);
    *page = 0;
}

/* ============================================================================
 * Get Page
 * ============================================================================ */
page_entry_t* get_page(uint32_t addr, int make, page_directory_t* dir) {
    addr /= PAGE_SIZE;
    uint32_t table_idx = addr / PAGE_ENTRIES;
    uint32_t page_idx = addr % PAGE_ENTRIES;

    if (dir->tables[table_idx]) {
        return &dir->tables[table_idx]->entries[page_idx];
    } else if (make) {
        uint32_t tmp;
        dir->tables[table_idx] = (page_table_t*)kmalloc_ap(sizeof(page_table_t), &tmp);
        memset(dir->tables[table_idx], 0, PAGE_SIZE);
        dir->tables_physical[table_idx] = tmp | PAGE_PRESENT | PAGE_WRITABLE;
        return &dir->tables[table_idx]->entries[page_idx];
    }
    return 0;
}

/* ============================================================================
 * Switch Page Directory
 * ============================================================================ */
void switch_page_directory(page_directory_t* dir) {
    current_directory = dir;
    write_cr3(dir->physical_addr);
}

/* ============================================================================
 * Page Fault Handler
 * ============================================================================ */
void page_fault_handler(void) {
    uint32_t fault_addr;
    asm volatile("mov %%cr2, %0" : "=r"(fault_addr));

    uint32_t error_code;
    asm volatile("mov 4(%%esp), %0" : "=r"(error_code));

    int present = error_code & 0x01;
    int rw = error_code & 0x02;
    int us = error_code & 0x04;

    /* Simple page fault handling - just allocate a frame */
    page_entry_t* page = get_page(fault_addr, 1, current_directory);
    if (page) {
        alloc_frame(page, 1, 1);
    }
}

/* ============================================================================
 * Simple Kernel Memory Allocator
 * ============================================================================ */
static uint32_t kmalloc_int(uint32_t sz, int align, uint32_t* phys) {
    if (align && (placement_address & 0xFFFFF000)) {
        placement_address &= 0xFFFFF000;
        placement_address += PAGE_SIZE;
    }
    if (phys) {
        *phys = placement_address;
    }
    uint32_t tmp = placement_address;
    placement_address += sz;
    return tmp;
}

uint32_t kmalloc(uint32_t sz) {
    return kmalloc_int(sz, 0, 0);
}

uint32_t kmalloc_a(uint32_t sz) {
    return kmalloc_int(sz, 1, 0);
}

uint32_t kmalloc_ap(uint32_t sz, uint32_t* phys) {
    return kmalloc_int(sz, 1, phys);
}

/* ============================================================================
 * Initialize Paging
 * ============================================================================ */
void init_paging(void) {
    /* Assume 16MB of memory */
    uint32_t mem_end_page = 0x1000000;
    nframes = mem_end_page / PAGE_SIZE;

    /* Allocate frame bitmap */
    frames_bitmap = (uint32_t*)kmalloc(INDEX_FROM_BIT(nframes) * sizeof(uint32_t));
    memset(frames_bitmap, 0, INDEX_FROM_BIT(nframes) * sizeof(uint32_t));

    /* Create kernel page directory */
    kernel_directory = (page_directory_t*)kmalloc_a(sizeof(page_directory_t));
    memset(kernel_directory, 0, sizeof(page_directory_t));

    /* Identity map first 4MB */
    int i = 0;
    for (i = 0; i < placement_address + PAGE_SIZE; i += PAGE_SIZE) {
        alloc_frame(get_page(i, 1, kernel_directory), 1, 1);
    }

    /* Map kernel to higher half (0xC0000000) */
    for (i = KERNEL_START; i < KERNEL_START + 0x400000; i += PAGE_SIZE) {
        alloc_frame(get_page(i, 1, kernel_directory), 1, 1);
    }

    /* Register page fault handler */
    /* (Already set up in IDT) */

    /* Switch to kernel directory */
    kernel_directory->physical_addr = (uint32_t)kernel_directory->tables_physical;
    switch_page_directory(kernel_directory);

    /* Enable paging */
    uint32_t cr0 = read_cr0();
    cr0 |= 0x80000000;
    asm volatile("mov %0, %%cr0" : : "r"(cr0));
}
