; Mystique OS Bootloader with Floppy Disk I/O
; Loads kernel from disk and jumps to it

org 0x7C00
bits 16

KERNEL_ADDR equ 0x10000; Load kernel at 0x10000
KERNEL_SECTORS equ 20; Read 20 sectors (10240 bytes)
KERNEL_SECTOR_START equ 2; Kernel starts at sector 2 (sector 1 = bootloader)

start:
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0x7C00

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

; Jump to kernel at 0x10000 (segment:offset = 0x1000:0x0000)
jmp 0x1000:0x0000

; Load kernel from disk into memory at KERNEL_ADDR
load_kernel:
; Set up buffer address (es:bx = 0x1000:0x0000 = 0x10000)
mov ax, 0x1000
mov es, ax
xor bx, bx

; Reset disk drive (floppy)
xor ax, ax
mov dl, 0x00; Drive 0x00 (floppy drive A:)
int 0x13

; Read kernel sectors from floppy
mov al, KERNEL_SECTORS; Number of sectors to read
mov ch, 0; Cylinder 0
mov cl, KERNEL_SECTOR_START; Start at sector 2
mov dh, 0; Head 0
mov dl, 0x00; Drive 0x00 (floppy drive)

mov ah, 0x02; Read sectors function
int 0x13; BIOS disk service

jc .disk_error

; Return success
mov ax, 1
ret

.disk_error:
xor ax, ax; Return 0 (failure)
ret

; Print string
; Input: si = pointer to string (null-terminated)
print_string:
.loop:
lodsb
cmp al, 0
je .done

mov ah, 0x0E; Teletype output
mov bh, 0; Page number
mov bl, 0x07; Color attribute
int 0x10
jmp .loop
.done:
ret

; Messages
msg_boot db "Mystique OS Bootloader", 13, 10, 0
msg_loading db "Loading kernel...", 13, 10, 0
msg_error db "Error: Failed to load kernel!", 13, 10, 0
msg_success db "Kernel loaded successfully! Entering kernel...", 13, 10, 0

times 510 - ($ - $$) db 0
dw 0xAA55
