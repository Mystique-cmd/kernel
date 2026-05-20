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

; Set video mode to 80x25 text mode (Mode 3) for consistency
mov ah, 0x00
mov al, 0x03
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

    ; *** New Paging Setup Code Starts Here ***
    call setup_paging
    ; *** New Paging Setup Code Ends Here ***

; Write "Protected Mode Enabled!" to video memory at 0xB8000
mov edi, 0xB8000
mov esi, pm_msg
mov ecx, pm_msg_len
.write_loop:
cmp ecx, 0
je .done_msg
mov al, byte [esi]
mov byte [edi], al
mov byte [edi + 1], 0x0F  ; White text on black background
add edi, 2
add esi, 1
dec ecx
jmp .write_loop

.done_msg:
    jmp $ ; Infinite loop after displaying message

; --- Paging Constants ---
PAGING_FLAG_PRESENT equ 0x001  ; Bit 0: Page is present in memory
PAGING_FLAG_RW      equ 0x002  ; Bit 1: Read/Write enabled

; --- Paging Functions ---
setup_paging:
    ; Clear page directory
    ; Use the address of the page_directory label
    mov edi, page_directory
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear page table
    ; Use the address of the page_table label
    mov edi, page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Setup first Page Directory Entry (PDE)
    ; Map virtual address 0-4MB to physical address 0-4MB
    ; PDE points to the physical address of page_table
    ; Flags: Present (P=1), Read/Write (RW=1)
    mov eax, page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [page_directory], eax

    ; Setup Page Table Entries (PTEs)
    ; Identity map first 4MB (0x00000000 - 0x003FFFFF)
    ; Each PTE maps a 4KB page
    mov edi, page_table
    xor ecx, ecx
.pte_loop:
    ; Physical address = ecx * 4KB
    mov eax, ecx
    shl eax, 12 ; Multiply by 4096 (2^12)
    ; Add flags: Present (P=1), Read/Write (RW=1)
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [edi + ecx * 4], eax
    inc ecx
    cmp ecx, 1024
    jne .pte_loop

    ; Load Page Directory Base Register (CR3)
    mov eax, page_directory
    mov cr3, eax

    ; Enable Paging by setting the PG bit (bit 31) in CR0
    mov eax, cr0
    or eax, 0x80000000 ; Set PG bit (bit 31)
    mov cr0, eax

    ret

; --- Paging Data Structures ---
; Reserve space for Page Directory and Page Table
; These will be appended to the end of the kernel.bin
; Ensure 4KB alignment for these structures.

align 4096 ; Align to a 4KB boundary
page_directory:
    resb 4096 ; 1024 entries * 4 bytes/entry = 4096 bytes (for PDE)

align 4096 ; Align to a 4KB boundary
page_table:
    resb 4096 ; 1024 entries * 4 bytes/entry = 4096 bytes (for PTE)
