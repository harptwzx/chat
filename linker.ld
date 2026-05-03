/* ============================================================================
 * Resurgam OS - Linker Script
 * ============================================================================ */

ENTRY(_start)

SECTIONS
{
    /* Kernel starts at 1MB */
    . = 0x100000;

    /* Text section */
    .text : ALIGN(4K)
    {
        *(.text)
        *(.text.*)
    }

    /* Read-only data */
    .rodata : ALIGN(4K)
    {
        *(.rodata)
        *(.rodata.*)
    }

    /* Initialized data */
    .data : ALIGN(4K)
    {
        *(.data)
        *(.data.*)
    }

    /* Uninitialized data */
    .bss : ALIGN(4K)
    {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

    /* End of kernel */
    end = .;
}
