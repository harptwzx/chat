; ============================================================================
; Resurgam OS - Kernel Assembly Entry
; 32-bit protected mode, multitasking setup, interrupt handling
; ============================================================================

BITS 32

; Kernel signature
kernel_sig: dw 0x5253       ; 'RS'

section .text
    global _start
    global load_idt
    global load_gdt
    global enable_paging
    global switch_task
    global inb
    global outb
    global io_wait
    global read_cr0
    global read_cr3
    global write_cr3
    global flush_tlb
    global enter_usermode
    global syscall_entry
    global get_esp
    global get_ebp
    global get_eflags
    global save_fpu
    global restore_fpu
    global enable_fpu
    global cpuid_check
    global halt_cpu

extern kernel_main
extern timer_handler
extern keyboard_handler
extern mouse_handler
extern syscall_handler
extern page_fault_handler
extern gpf_handler
extern ide_handler

; ============================================================================
; Kernel Entry Point
; ============================================================================
_start:
    ; Setup stack
    mov esp, 0x8F000

    ; Save multiboot info
    mov [multiboot_magic], eax
    mov [multiboot_info], ebx

    ; Clear BSS
    mov edi, bss_start
    mov ecx, bss_end
    sub ecx, edi
    xor eax, eax
    rep stosb

    ; Call C kernel main
    call kernel_main

    ; Halt if kernel_main returns
.halt:
    cli
    hlt
    jmp .halt

; ============================================================================
; Port I/O
; ============================================================================
inb:
    mov dx, [esp + 4]
    in al, dx
    ret

outb:
    mov dx, [esp + 4]
    mov al, [esp + 8]
    out dx, al
    ret

io_wait:
    jmp $+2
    jmp $+2
    ret

; ============================================================================
; CR Registers
; ============================================================================
read_cr0:
    mov eax, cr0
    ret

read_cr3:
    mov eax, cr3
    ret

write_cr3:
    mov eax, [esp + 4]
    mov cr3, eax
    ret

flush_tlb:
    mov eax, cr3
    mov cr3, eax
    ret

; ============================================================================
; GDT/IDT Loading
; ============================================================================
load_gdt:
    mov eax, [esp + 4]
    lgdt [eax]
    ret

load_idt:
    mov eax, [esp + 4]
    lidt [eax]
    ret

; ============================================================================
; Interrupt Service Routines (ISRs)
; ============================================================================
%macro ISR_NOERR 1
isr%1:
    cli
    push dword 0
    push dword %1
    jmp isr_common
%endmacro

%macro ISR_ERR 1
isr%1:
    cli
    push dword %1
    jmp isr_common
%endmacro

ISR_NOERR 0
ISR_NOERR 1
ISR_NOERR 2
ISR_NOERR 3
ISR_NOERR 4
ISR_NOERR 5
ISR_NOERR 6
ISR_NOERR 7
ISR_ERR   8
ISR_NOERR 9
ISR_ERR   10
ISR_ERR   11
ISR_ERR   12
ISR_ERR   13
ISR_ERR   14
ISR_NOERR 15
ISR_NOERR 16
ISR_ERR   17
ISR_NOERR 18
ISR_NOERR 19
ISR_NOERR 20
ISR_NOERR 21
ISR_NOERR 22
ISR_NOERR 23
ISR_NOERR 24
ISR_NOERR 25
ISR_NOERR 26
ISR_NOERR 27
ISR_NOERR 28
ISR_NOERR 29
ISR_NOERR 30
ISR_NOERR 31

; IRQ handlers (remapped to 32-47)
ISR_NOERR 32    ; Timer
ISR_NOERR 33    ; Keyboard
ISR_NOERR 34    ; Cascade
ISR_NOERR 35    ; COM2
ISR_NOERR 36    ; COM1
ISR_NOERR 37    ; LPT2
ISR_NOERR 38    ; Floppy
ISR_NOERR 39    ; LPT1
ISR_NOERR 40    ; RTC
ISR_NOERR 41    ; ACPI
ISR_NOERR 42    ; Available
ISR_NOERR 43    ; Available
ISR_NOERR 44    ; PS/2 Mouse
ISR_NOERR 45    ; FPU
ISR_NOERR 46    ; Primary IDE
ISR_NOERR 47    ; Secondary IDE

isr_common:
    pusha
    push ds
    push es
    push fs
    push gs

    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov eax, [esp + 48]

    cmp eax, 32
    je .timer
    cmp eax, 33
    je .keyboard
    cmp eax, 44
    je .mouse
    cmp eax, 14
    je .page_fault
    cmp eax, 13
    je .gpf
    cmp eax, 46
    je .ide
    cmp eax, 47
    je .ide
    jmp .done

.timer:
    call timer_handler
    jmp .done
.keyboard:
    call keyboard_handler
    jmp .done
.mouse:
    call mouse_handler
    jmp .done
.page_fault:
    call page_fault_handler
    jmp .done
.gpf:
    call gpf_handler
    jmp .done
.ide:
    call ide_handler

.done:
    mov al, 0x20
    out 0x20, al
    cmp eax, 40
    jb .no_slave
    out 0xA0, al
.no_slave:
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8
    iret

; ============================================================================
; Syscall Entry (int 0x80)
; ============================================================================
syscall_entry:
    cli
    pusha
    push ds
    push es
    push fs
    push gs

    mov ax, 0x10
    mov ds, ax
    mov es, ax

    push edx
    push ecx
    push ebx
    push eax
    call syscall_handler
    add esp, 16

    mov [esp + 28], eax

    pop gs
    pop fs
    pop es
    pop ds
    popa
    iret

; ============================================================================
; Task Switching
; ============================================================================
switch_task:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    push edi
    mov eax, [ebp + 8]
    mov [eax], esp
    mov eax, [ebp + 12]
    mov esp, [eax]
    pop edi
    pop esi
    pop ebx
    pop ebp
    ret

; ============================================================================
; Usermode Entry
; ============================================================================
enter_usermode:
    mov ax, 0x23
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, esp
    push 0x23
    push eax
    pushfd
    pop eax
    or eax, 0x200
    push eax
    push 0x1B
    push .user_entry
    iret
.user_entry:
    ret

; ============================================================================
; FPU Operations
; ============================================================================
enable_fpu:
    mov eax, cr0
    and eax, 0xFFFFFFFB
    or eax, 0x00000002
    mov cr0, eax
    fninit
    ret

save_fpu:
    mov eax, [esp + 4]
    fnsave [eax]
    ret

restore_fpu:
    mov eax, [esp + 4]
    frstor [eax]
    ret

; ============================================================================
; CPUID
; ============================================================================
cpuid_check:
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    jz .no_cpuid
    mov eax, 1
    ret
.no_cpuid:
    xor eax, eax
    ret

; ============================================================================
; Utility
; ============================================================================
get_esp:
    mov eax, esp
    ret

get_ebp:
    mov eax, ebp
    ret

get_eflags:
    pushfd
    pop eax
    ret

halt_cpu:
    cli
    hlt
    ret

; ============================================================================
; ISR Table
; ============================================================================
global isr_table
isr_table:
%assign i 0
%rep 48
    dd isr%+i
%assign i i+1
%endrep

; ============================================================================
; Data
; ============================================================================
section .data
multiboot_magic: dd 0
multiboot_info:  dd 0

section .bss
bss_start:
resb 65536
bss_end:
