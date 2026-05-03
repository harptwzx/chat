; ============================================================================
; Resurgam OS - Boot Sector & Stage2 Loader
; 32-bit Protected Mode OS with GUI, Mouse, Keyboard, CLI
; ============================================================================

BITS 16
ORG 0x7C00

; BIOS Parameter Block (BPB) for floppy emulation
jmp short start
nop
OEMName:          db 'RESURGAM'
BytesPerSector:   dw 512
SectorsPerCluster:db 1
ReservedSectors:  dw 1
NumFATs:          db 2
RootEntries:      dw 224
TotalSectors:     dw 2880
MediaDescriptor:  db 0xF0
SectorsPerFAT:    dw 9
SectorsPerTrack:  dw 18
NumHeads:         dw 2
HiddenSectors:    dd 0
TotalSectorsBig:  dd 0
DriveNum:         db 0
Reserved1:        db 0
BootSignature:    db 0x29
VolumeID:         dd 0x20260429
VolumeLabel:      db 'RESURGAM   '
FileSystemType:   db 'FAT12   '

start:
    ; Setup segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Save boot drive
    mov [BootDrive], dl

    ; Print boot message
    mov si, msg_boot
    call print_string

    ; Enable A20 line
    call enable_a20

    ; Load stage2 loader (sectors 2-16, 15 sectors = 7680 bytes)
    mov si, msg_load
    call print_string

    mov ax, 0x0000      ; Load to 0x0000:0x7E00 (right after boot sector)
    mov es, ax
    mov bx, 0x7E00
    mov ah, 0x02        ; Read sectors
    mov al, 15          ; Number of sectors
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Sector 2
    mov dh, 0           ; Head 0
    mov dl, [BootDrive]
    int 0x13
    jc disk_error

    ; Verify stage2 signature
    mov ax, [0x7E00]
    cmp ax, 0x5245      ; 'RE'
    jne stage2_error

    ; Jump to stage2
    jmp 0x0000:0x7E02

disk_error:
    mov si, msg_disk_err
    call print_string
    jmp $

stage2_error:
    mov si, msg_stage2_err
    call print_string
    jmp $

; ============================================================================
; Print String (SI = string address)
; ============================================================================
print_string:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ============================================================================
; Enable A20 Line
; ============================================================================
enable_a20:
    pusha
    ; Try BIOS method first
    mov ax, 0x2401
    int 0x15
    jc .try_keyboard
    test ah, ah
    jz .done
.try_keyboard:
    ; Keyboard controller method
    call a20_wait
    mov al, 0xAD
    out 0x64, al
    call a20_wait
    mov al, 0xD0
    out 0x64, al
    call a20_wait2
    in al, 0x60
    push ax
    call a20_wait
    mov al, 0xD1
    out 0x64, al
    call a20_wait
    pop ax
    or al, 2
    out 0x60, al
    call a20_wait
    mov al, 0xAE
    out 0x64, al
    call a20_wait
.done:
    popa
    ret

a20_wait:
    in al, 0x64
    test al, 2
    jnz a20_wait
    ret

a20_wait2:
    in al, 0x64
    test al, 1
    jz a20_wait2
    ret

; ============================================================================
; Data
; ============================================================================
BootDrive:      db 0
msg_boot:       db 0x0D, 0x0A, 'Resurgam OS v1.0', 0x0D, 0x0A, 0
msg_load:       db 'Loading kernel...', 0x0D, 0x0A, 0
msg_disk_err:   db 'Disk error!', 0x0D, 0x0A, 0
msg_stage2_err: db 'Stage2 error!', 0x0D, 0x0A, 0

; Pad to 510 bytes and add boot signature
times 510-($-$$) db 0
dw 0xAA55
