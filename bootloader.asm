; Mystique OS Bootloader with Floppy Disk I/O
; Loads the kernel from disk and jumps to it.

org 0x7C00
bits 16

KERNEL_ADDR equ 0x10000
KERNEL_SECTORS equ 64
KERNEL_SECTOR_START equ 1
FLOPPY_DRIVE equ 0x00

start:
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    call serial_init

    ; Display boot message
    mov si, msg_boot
    call print_string

    ; Load kernel from disk
    mov si, msg_loading
    call print_string
    call load_kernel

    ; Check if load was successful
    cmp ax, 0
    jne kernel_loaded
    mov si, msg_error
    call print_string
    jmp $

kernel_loaded:
    mov si, msg_success
    call print_string

    ; Jump to the kernel's physical entry point.
    jmp 0x1000:0x0000

; Load kernel from disk into memory at KERNEL_ADDR.
; Use BIOS extended disk read (INT 13h, AH=0x42) to avoid CHS track-boundary issues.
load_kernel:
    ; Set up buffer address (es:bx = 0x1000:0x0000 = 0x10000)
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    ; Build disk address packet.
    mov si, disk_packet
    mov byte [si], 0x10
    mov byte [si + 1], 0x00
    mov word [si + 2], KERNEL_SECTORS
    mov word [si + 4], bx
    mov word [si + 6], es
    mov dword [si + 8], KERNEL_SECTOR_START
    mov dword [si + 12], 0x00

    ; Reset disk drive and read kernel via LBA.
    xor ax, ax
    mov dl, FLOPPY_DRIVE
    int 0x13
    jc .disk_error

    mov dl, FLOPPY_DRIVE
    mov ah, 0x42
    mov si, disk_packet
    int 0x13
    jc .disk_error

    ; Return success
    mov ax, 1
    ret

.disk_error:
    xor ax, ax
    ret

serial_init:
    mov dx, 0x3F9
    xor al, al
    out dx, al

    mov dx, 0x3FB
    mov al, 0x80
    out dx, al

    mov dx, 0x3F8
    mov al, 0x03
    out dx, al

    mov dx, 0x3F9
    mov al, 0x00
    out dx, al

    mov dx, 0x3FB
    mov al, 0x03
    out dx, al

    mov dx, 0x3FA
    mov al, 0xC7
    out dx, al

    mov dx, 0x3FC
    mov al, 0x0B
    out dx, al
    ret

serial_write_char:
    push ax
    mov dx, 0x3FD
.wait:
    in al, dx
    test al, 0x20
    jz .wait
    mov dx, 0x3F8
    mov al, dl
    out dx, al
    pop ax
    ret

; Print string.
; Input: SI = pointer to a null-terminated string.
print_string:
.loop:
    lodsb
    cmp al, 0
    je .done

    mov dl, al
    call serial_write_char

    mov ah, 0x0E
    mov bh, 0
    mov bl, 0x07
    int 0x10
    jmp .loop
.done:
    ret

; Messages
msg_boot db "Mystique OS Bootloader", 13, 10, 0
msg_loading db "Loading kernel...", 13, 10, 0
msg_error db "Error: Failed to load kernel!", 13, 10, 0
msg_success db "Kernel loaded successfully! Entering kernel...", 13, 10, 0

align 4
disk_packet:
    db 0x10
    db 0x00
    dw KERNEL_SECTORS
    dw 0x0000
    dw 0x1000
    dd KERNEL_SECTOR_START
    dd 0x00000000

times 510 - ($ - $$) db 0
dw 0xAA55
