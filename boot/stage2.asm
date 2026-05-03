; ============================================================================
; Resurgam OS - Stage2 Loader
; Sets up GDT, enters protected mode, loads kernel to 0x100000
; ============================================================================

BITS 16
ORG 0x7E00

; Signature check
sig: dw 0x5245          ; 'RE'

start_stage2:
    ; Setup segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Print stage2 message
    mov si, msg_stage2
    call print_string_16

    ; Get memory map using BIOS E820
    call get_memory_map

    ; Load kernel from disk (sectors 17-81, 64 sectors = 32KB)
    ; Kernel will be loaded to 0x100000 (1MB) via unreal mode
    mov si, msg_load_kernel
    call print_string_16

    ; Use BIOS int 13h extended read (LBA)
    mov si, DAP
    mov ah, 0x42
    mov dl, [BootDrive]
    int 0x13
    jc disk_error_16

    ; Verify kernel signature
    mov ax, 0xFFFF
    mov ds, ax
    mov si, 0x0010      ; 0xFFFF:0x0010 = 0x100000
    mov ax, [si]
    cmp ax, 0x5253      ; 'RS' (Resurgam)
    jne kernel_error

    ; Setup GDT
    mov si, msg_gdt
    call print_string_16

    cli
    lgdt [gdtr]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp 0x08:protected_mode

; ============================================================================
; 16-bit helper functions
; ============================================================================
print_string_16:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    popa
    ret

disk_error_16:
    mov si, msg_disk_err
    call print_string_16
    jmp $

kernel_error:
    mov si, msg_kernel_err
    call print_string_16
    jmp $

; ============================================================================
; Get Memory Map (E820)
; ============================================================================
get_memory_map:
    pusha
    mov di, 0x8004      ; Store at 0x8000 + 4
    xor ebx, ebx
    xor bp, bp
    mov edx, 0x534D4150 ; 'SMAP'
    mov eax, 0xE820
    mov [es:di + 20], dword 1
    mov ecx, 24
    int 0x15
    jc .failed
    mov edx, 0x534D4150
    cmp eax, edx
    jne .failed
    test ebx, ebx
    je .failed
    jmp .start
.next:
    mov eax, 0xE820
    mov [es:di + 20], dword 1
    mov ecx, 24
    int 0x15
    jc .done
    mov edx, 0x534D4150
.start:
    jcxz .skip
    cmp cl, 20
    jbe .notext
    test byte [es:di + 20], 1
    je .skip
.notext:
    mov ecx, [es:di + 8]
    or ecx, [es:di + 12]
    jz .skip
    inc bp
    add di, 24
.skip:
    test ebx, ebx
    jne .next
.done:
    mov [0x8000], bp
    clc
    popa
    ret
.failed:
    stc
    popa
    ret

; ============================================================================
; Disk Address Packet (DAP)
; ============================================================================
DAP:
    db 0x10             ; Size of DAP
    db 0                ; Reserved
    dw 64               ; Number of sectors (32KB kernel)
    dw 0x0000           ; Offset
    dw 0xFFFF           ; Segment (0xFFFF:0x0000 = 0xFFFF0, but we use 0xFFFF:0x0010 = 0x100000)
    dd 17               ; Start LBA (sector 17)
    dd 0

BootDrive:      db 0
msg_stage2:     db 'Stage2 loaded.', 0x0D, 0x0A, 0
msg_load_kernel:db 'Loading kernel...', 0x0D, 0x0A, 0
msg_gdt:        db 'Setting up GDT...', 0x0D, 0x0A, 0
msg_disk_err:   db 'Disk read error!', 0x0D, 0x0A, 0
msg_kernel_err: db 'Kernel signature error!', 0x0D, 0x0A, 0

; ============================================================================
; GDT (Global Descriptor Table)
; ============================================================================
gdt_start:
    ; Null descriptor
    dq 0

    ; Code segment (0x08)
    dw 0xFFFF           ; Limit low
    dw 0x0000           ; Base low
    db 0x00             ; Base middle
    db 10011010b        ; Access: present, ring 0, code, executable, readable
    db 11001111b        ; Flags: 4KB granularity, 32-bit, limit high
    db 0x00             ; Base high

    ; Data segment (0x10)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b        ; Access: present, ring 0, data, writable
    db 11001111b
    db 0x00

    ; Video segment (0x18) - linear framebuffer or VGA
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b
    db 11001111b
    db 0x00

gdt_end:

gdtr:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Pad to fill remaining sectors
times 7680-($-$$) db 0

; ============================================================================
; 32-bit Protected Mode Code
; ============================================================================
BITS 32

protected_mode:
    ; Setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000    ; Stack at 0x90000

    ; Clear screen (blue background)
    mov edi, 0xB8000
    mov ecx, 2000       ; 80x25
    mov ax, 0x1F20      ; Blue bg, white fg, space
    rep stosw

    ; Print protected mode message
    mov esi, msg_prot
    mov edi, 0xB8000 + 160  ; Line 1
    call print_string_32

    ; Jump to kernel at 0x100000
    jmp 0x100004        ; Skip signature

print_string_32:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov [edi], al
    mov byte [edi + 1], 0x1F
    add edi, 2
    jmp .loop
.done:
    popa
    ret

msg_prot: db 'Protected mode enabled. Jumping to kernel...', 0
