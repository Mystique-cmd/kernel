bits 16
org 0x10000

KERNEL_PHYSICAL_BASE equ 0x10000
KERNEL_VIRTUAL_BASE equ 0xC0000000
KERNEL_STACK_TOP equ 0xC000FFFC

; GDT setup
GDT_NULL equ 0x00
GDT_CODE equ 0x08
GDT_DATA equ 0x10

gdt_start:
dq 0x0000000000000000

; Code segment: 4GB, executable, readable
dw 0xFFFF
 dw 0x0000
db 0x00
db 0x9A
db 0xCF
db 0x00

; Data segment: 4GB, writable
dw 0xFFFF
dw 0x0000
db 0x00
db 0x92
db 0xCF
db 0x00

gdt_end:

gdt_descriptor:
dw gdt_end - gdt_start - 1
dd gdt_start

CODE_SEL equ 0x08
DATA_SEL equ 0x10

pm_msg db "Protected Mode Enabled!"
pm_msg_len equ $ - pm_msg

kernel_start:
    cld
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE

    ; Set video mode to 80x25 text mode.
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    cli
    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 1
    mov cr0, eax

    jmp CODE_SEL:protected_start_abs

bits 32
protected_start_abs:
    mov ax, DATA_SEL
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; Enable paging and switch execution to the higher-half kernel mapping.
    call setup_paging
    call setup_user_paging

    mov edi, 0xB8000
    mov esi, pm_msg
    mov ecx, pm_msg_len
.write_loop:
    cmp ecx, 0
    je .done_msg
    mov al, byte [esi]
    mov byte [edi], al
    mov byte [edi + 1], 0x0F
    add edi, 2
    add esi, 1
    dec ecx
    jmp .write_loop

.done_msg:
    jmp $

PAGING_FLAG_PRESENT equ 0x001
PAGING_FLAG_RW      equ 0x002
PAGING_FLAG_USER    equ 0x004

setup_paging:
    cld

    mov edi, page_directory
    xor eax, eax
    mov ecx, 1024
    rep stosd

    mov edi, page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    mov eax, page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [page_directory], eax

    mov edi, page_table
    xor ecx, ecx
.pte_loop:
    mov eax, ecx
    shl eax, 12
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [edi + ecx * 4], eax
    inc ecx
    cmp ecx, 1024
    jne .pte_loop

    mov edi, kernel_page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    mov eax, kernel_page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [page_directory + (KERNEL_VIRTUAL_BASE >> 22) * 4], eax

    mov ebx, KERNEL_PHYSICAL_BASE
    mov edi, kernel_page_table
    xor ecx, ecx
.kernel_pte_loop:
    mov eax, ebx
    mov edx, ecx
    shl edx, 12
    add eax, edx
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW
    mov dword [edi + ecx * 4], eax
    inc ecx
    cmp ecx, 256
    jne .kernel_pte_loop

    mov eax, page_directory
    mov cr3, eax

    mov eax, cr0
    or eax, 0x80000000
    mov cr0, eax

    mov esp, KERNEL_STACK_TOP
    jmp CODE_SEL:(protected_start_abs + (KERNEL_VIRTUAL_BASE - KERNEL_PHYSICAL_BASE))

align 4096
page_directory:
    resb 4096

align 4096
page_table:
    resb 4096

align 4096
kernel_page_table:
    resb 4096

; User-space paging is experimental and not used by the default boot path.
USER_VIRTUAL_BASE equ 0x00400000
USER_PHYSICAL_BASE equ 0x00000000
USER_MAPPING_SIZE_PAGES equ 256

align 4096
user_page_directory:
    resb 4096

align 4096
user_page_table:
    resb 4096

setup_user_paging:
    cld

    mov edi, user_page_directory
    xor eax, eax
    mov ecx, 1024
    rep stosd

    mov edi, user_page_table
    xor eax, eax
    mov ecx, 1024
    rep stosd

    mov eax, user_page_table
    or eax, PAGING_FLAG_PRESENT | PAGING_FLAG_RW | PAGING_FLAG_USER
    mov dword [user_page_directory + (USER_VIRTUAL_BASE >> 22) * 4], eax

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

switch_to_user_space:
    mov eax, user_page_directory
    mov cr3, eax
    ret
