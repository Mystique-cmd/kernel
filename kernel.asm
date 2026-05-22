bits 16

KERNEL_PHYSICAL_BASE equ 0x10000
KERNEL_VIRTUAL_BASE equ 0xC0000000

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
    call setup_user_paging
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
PAGING_FLAG_USER   equ 0x004  ; Bit 2: User/supervisor (1=user)

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

    ; --- New: Setup higher-half mapping for kernel ---
    ; Clear kernel_page_table
    mov edi, kernel_page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Setup PDE for higher-half kernel (0xC0000000)
    ; This PDE will point to kernel_page_table
    ; Index: 0xC0000000 / 0x400000 = 0x300 (768)
    mov eax, kernel_page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [page_directory + (KERNEL_VIRTUAL_BASE >> 22) * 4], eax ; PDE at index 768

    ; Setup PTEs for the kernel in kernel_page_table
    ; Map physical address KERNEL_PHYSICAL_BASE to virtual address KERNEL_VIRTUAL_BASE
    ; Map 256 pages (1MB) for the kernel
    mov ebx, KERNEL_PHYSICAL_BASE ; Physical address for kernel start
    mov edi, kernel_page_table
    xor ecx, ecx ; Loop counter for PTEs
.kernel_pte_loop:
    ; Calculate physical address for this PTE
    mov eax, ebx
    mov edx, ecx
    shl edx, 12
    add eax, edx

    ; Add flags: Present (P=1), Read/Write (RW=1)
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [edi + ecx * 4], eax

    inc ecx
    cmp ecx, 256 ; Map 256 pages (1MB) for the kernel
    jne .kernel_pte_loop


    ; Load Page Directory Base Register (CR3)
    mov eax, page_directory
    mov cr3, eax

    ; Enable Paging by setting the PG bit (bit 31) in CR0
    mov eax, cr0
    or eax, 0x80000000 ; Set PG bit (bit 31)
    mov cr0, eax

    ; Now we are running in the higher half.
    ; Adjust the stack to the higher half as well.
    mov ebp, 0xC0000000 + 0xFFFE ; Example stack in higher half
    mov esp, ebp

    ; Far jump to protected mode (using explicit absolute address)
    ; Now, jump to the virtual address of protected_start_abs
    mov eax, protected_start_abs
    add eax, KERNEL_VIRTUAL_BASE - KERNEL_PHYSICAL_BASE
    jmp CODE_SEL:protected_start_abs

; --- Paging Data Structures ---
; Reserve space for Page Directory and Page Table
; These will be appended to the end of the kernel.bin
; Ensure 4KB alignment for these structures.

; -----------------------------
; Kernel paging structures
; -----------------------------
align 4096 ; Align to a 4KB boundary
page_directory:
    resb 4096 ; 1024 entries * 4 bytes/entry = 4096 bytes (for PDE)

align 4096 ; Align to a 4KB boundary
page_table:
    resb 4096 ; 1024 entries * 4 bytes/entry = 4096 bytes (for PTE)

align 4096 ; Align to a 4KB boundary
kernel_page_table:
    resb 4096 ; 1024 entries * 4 bytes/entry = 4096 bytes (for PTEs for kernel higher half)

; -----------------------------
; User paging structures
; -----------------------------
; Separate set of page tables for a user-space address space.
; NOTE: Currently, the OS does not load a real user program yet.
; This only sets up the data structures + mappings.

align 4096 ; Align to a 4KB boundary
user_page_directory:
    resb 4096 ; 1024 PDEs

align 4096 ; Align to a 4KB boundary
user_page_table:
    resb 4096 ; 1024 PTEs

; -----------------------------
; User-space constants
; -----------------------------
; Virtual base for the user program mapping.
USER_VIRTUAL_BASE equ 0x00400000 ; 4MB

; Physical base where the user program would live.
; (For now we map it as if it were loaded here.)
USER_PHYSICAL_BASE equ 0x00000000

; Maps 1MB of user virtual memory.
USER_MAPPING_SIZE_PAGES equ 256

; -----------------------------
; User paging setup routines
; -----------------------------

; setup_user_paging:
;   Builds a separate page directory/table for user-space.
;   Does NOT switch CR3.
setup_user_paging:
    ; Clear user page directory
    mov edi, user_page_directory
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Clear user page table
    mov edi, user_page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    ; Install a PDE for USER_VIRTUAL_BASE
    ; PDE index = USER_VIRTUAL_BASE / 4MB = USER_VIRTUAL_BASE >> 22
    mov eax, user_page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW | PAGING_FLAG_USER
    mov dword [user_page_directory + (USER_VIRTUAL_BASE >> 22) * 4], eax

    ; Fill PTEs for a contiguous region starting at USER_PHYSICAL_BASE.
    mov edi, user_page_table
    mov ecx, 0
    mov ebx, USER_PHYSICAL_BASE

.user_pte_loop:
    mov eax, ebx
    mov edx, ecx
    shl edx, 12
    add eax, edx
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW | PAGING_FLAG_USER
    mov dword [edi + ecx * 4], eax

    inc ecx
    cmp ecx, USER_MAPPING_SIZE_PAGES
    jne .user_pte_loop

    ret

; switch_to_user_space:
;   Switches CR3 to the user page directory.
;   Assumes paging is already enabled.
switch_to_user_space:
    mov eax, user_page_directory
    mov cr3, eax
    ret

; (Kernel paging structures must remain defined after the functions.)
