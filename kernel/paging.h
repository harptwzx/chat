/* ============================================================================
 * Resurgam OS - Paging Header
 * ============================================================================ */

#ifndef PAGING_H
#define PAGING_H

#include "kernel.h"

#define PAGE_SIZE       4096
#define PAGE_ENTRIES    1024
#define KERNEL_START    0xC0000000

/* Page flags */
#define PAGE_PRESENT    0x001
#define PAGE_WRITABLE   0x002
#define PAGE_USER       0x004
#define PAGE_WRITETHRU  0x008
#define PAGE_NOCACHE    0x010
#define PAGE_ACCESSED   0x020
#define PAGE_DIRTY      0x040
#define PAGE_GLOBAL     0x100
#define PAGE_FRAME      0xFFFFF000

/* Page directory/table entry */
typedef uint32_t page_entry_t;

/* Page table */
typedef struct {
    page_entry_t entries[PAGE_ENTRIES];
} page_table_t;

/* Page directory */
typedef struct {
    page_table_t* tables[PAGE_ENTRIES];
    page_entry_t tables_physical[PAGE_ENTRIES];
    uint32_t physical_addr;
} page_directory_t;

/* Functions */
void init_paging(void);
void switch_page_directory(page_directory_t* dir);
page_entry_t* get_page(uint32_t addr, int make, page_directory_t* dir);
void alloc_frame(page_entry_t* page, int is_kernel, int is_writable);
void free_frame(page_entry_t* page);
void page_fault_handler(void);

#endif
