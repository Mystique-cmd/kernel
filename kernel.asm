org 0x10000
bits 16

gdt_start:
dq 0x0000000000000000

; Code segment: 4GB, executable, readable
dw 0xFFFF        ; Limit (15:0)
dw 0x0000        ; Base (15:0)
db 0x00          ; Base (23:16)
db 0x9A          ; Access byte: 10011010 (present, privilege 00, code, readable)
db 0xCF          ; Flags: 11001111 (granularity 4KB, 32-bit)
db 0x00          ; Base (31:24)

; Data segment: 4GB, writable
dw 0xFFFF        ; Limit (15:0)
dw 0x0000        ; Base (15:0)
db 0x00          ; Base (23:16)
db 0x92          ; Access byte: 10010010 (present, privilege 00, data, writable)
db 0xCF          ; Flags: 11001111 (granularity 4KB, 32-bit)
db 0x00          ; Base (31:24)

gdt_end:

gdt_descriptor:
dw gdt_end - gdt_start - 1 ; Limit - the size of the GDT( 16-bit)
dd gdt_start ;Base - the start address ( 32-bit)

CODE_SEL equ 8
DATA_SEL equ 16

pm_msg db "Protected Mode Enabled!"
pm_msg_len equ $ - pm_msg

kernel_start:
xor ax, ax
mov ds, ax
mov es, ax
mov ss, ax
mov sp, 0xFFFE

; Print using BIOS (we know this works)
mov al, 'K'
mov ah, 0x0E
int 0x10

mov al, 'E'
mov ah, 0x0E
int 0x10

mov al, 'R'
mov ah, 0x0E
int 0x10

; Now try to enter protected mode
cli

; Load GDT
lgdt [gdt_descriptor]

; Set PE bit
mov eax, cr0
or eax, 1
mov cr0, eax

; Far jump to protected mode (using explicit absolute address)
jmp CODE_SEL:protected_start_abs

bits 32
protected_start_abs:
mov ax, DATA_SEL
mov ds, ax
mov es, ax
mov ss, ax

; Test: Overwrite the first character of pm_msg with 'X'
mov byte [pm_msg], 'X'

jmp $ ; Halt the system after the write

times 1024 - ($ - $$) db 0
