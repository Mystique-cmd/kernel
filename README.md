# Mystique OS Bootloader

A 512-byte x86 boot sector that loads the OS kernel from disk and transfers control to it.

## Prerequisites

Before running the bootloader, ensure you have the following tools installed:

- **NASM** (Netwide Assembler) - to assemble the `.asm` file
- **QEMU** (Quick Emulator) - to emulate and run the bootloader

### Installing Dependencies

**On Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install nasm qemu-system-x86
```

**On Fedora/RHEL:**
```bash
sudo dnf install nasm qemu-system-x86
```

**On macOS (using Homebrew):**
```bash
brew install nasm qemu
```

**On Windows:**
- Download NASM from https://www.nasm.us/
- Download QEMU from https://www.qemu.org/download/

## Running the Bootloader and Kernel

### Step 1: Assemble the Bootloader and Kernel

Convert the assembly source files into binary:

```bash
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin
```

This creates:
- `bootloader.bin` - 512 bytes (bootloader)
- `kernel.bin` - At least 512 bytes (kernel)

### Step 2: Create a Disk Image

Create a raw disk image containing the bootloader and kernel:

```bash
# Create a 1MB disk image filled with zeros
dd if=/dev/zero of=disk.img bs=1M count=1

# Write bootloader to sector 0 (boot sector)
dd if=bootloader.bin of=disk.img bs=512 count=1 conv=notrunc

# Write kernel to sector 1+
dd if=kernel.bin of=disk.img bs=512 seek=1 conv=notrunc
```

### Step 3: Run in QEMU

Boot the disk image as a floppy drive in QEMU (recommended for better BIOS support):

```bash
qemu-system-x86_64 -fda disk.img
```

Or alternatively:
```bash
qemu-system-x86_64 -drive file=disk.img,format=raw,if=floppy
```

### Expected Output

The QEMU window will display:
```
Mystique OS Bootloader
Loading kernel...
Kernel loaded successfully! Entering kernel...
Protected Mode Enabled!
```
Then it will hang in an infinite loop (normal behavior). To exit QEMU, press `Ctrl+Alt+Q` or close the window.

## Architecture: Bootloader vs Kernel

**Why are they separate files?**

The bootloader and kernel have different roles and constraints:

### Bootloader (bootloader.asm)
- **Fixed size**: Exactly 512 bytes (1 sector)
- **Purpose**: Initialize hardware and load the kernel from disk
- **Location**: Sector 0 (loaded by BIOS at 0x7C00)
- **Loaded by**: BIOS automatically on boot
- **Cannot grow**: Limited to 512 bytes; uses BIOS services

### Kernel (kernel.asm)
- **Variable size**: Can grow to multiple sectors/kilobytes
- **Purpose**: Main OS code (paging, memory protection, user programs, etc.)
- **Location**: Sectors 1+ (loaded by bootloader at 0x10000)
- **Loaded by**: Bootloader via disk I/O (int 0x13)
- **Expandable**: Can implement full OS features

**Boot sequence:**
```
1. BIOS loads bootloader from sector 0 → 0x7C00
2. Bootloader displays messages
3. Bootloader reads kernel from sectors 1+ → 0x10000 (using BIOS int 0x13)
4. Bootloader jumps to kernel at 0x10000 (physical address)
5. Kernel sets up GDT and enters Protected Mode
6. Kernel sets up paging, mapping itself to a higher virtual address (e.g., 0xC0000000)
7. Kernel performs a far jump to its new virtual address and continues execution
8. Kernel runs OS code from the higher virtual address
```

## Memory Management (Paging and Higher-Half Kernel)

The kernel now implements basic memory management using paging.

### Why Paging?
Paging provides memory protection, allows for virtual memory, and isolates processes. Each program (including the kernel) gets its own view of memory, enhancing stability and security.

### Higher-Half Kernel
To leave the lower virtual address space (0x00000000 to 0xBFFFFFFF) free for user-space applications, the kernel itself is mapped to a "higher half" of the virtual address space, starting from `0xC0000000`.

-   **Physical Load Address:** The kernel is physically loaded by the bootloader at `0x10000`.
-   **Virtual Execution Address:** After paging is enabled, the kernel code executes from virtual address `0xC0000000`. This means any internal references within the kernel are resolved to this higher virtual address, while the actual physical memory remains at `0x10000`.

This setup allows for a clean separation between kernel and user memory spaces, a fundamental concept in modern operating systems.

## What Each Component Does

### Bootloader
1. **Displays boot messages** - Shows loading status
2. **Loads kernel from disk** - Reads sectors 1+ from the hard disk using BIOS int 0x13
3. **Verifies load success** - Checks if kernel loaded without errors
4. **Transfers control** - Jumps to kernel entry point at 0x10000

### Kernel
1. **Initializes kernel environment** - Sets up segments and stack
2. **Sets up Paging and Higher-Half Kernel** - Configures memory management to run in a higher virtual address space (`0xC0000000`).
3. **Prints kernel message** - Confirms successful load and protected mode operation
4. **Ready for expansion** - Framework for advanced OS features

## Bootloader Configuration

Edit these constants in `bootloader.asm` to customize behavior:

```asm
KERNEL_ADDR equ 0x10000		; Memory address to load kernel
KERNEL_SECTORS equ 2			; Number of sectors to read (each = 512 bytes)
KERNEL_SECTOR_START equ 2		; Starting sector on disk (2 = after bootloader)
```

**Important notes:**
- **Drive**: Uses floppy drive (0x00) for better BIOS compatibility in QEMU
- **Sector 1**: Contains bootloader (512 bytes)
- **Sectors 2+**: Contain kernel code
- Adjust `KERNEL_SECTORS` based on your kernel size

## Files

- `bootloader.asm` - Bootloader source code (loads kernel from disk)
- `kernel.asm` - Kernel source code (entry point for OS)
- `bootloader.bin` - Compiled bootloader (created after assembly)
- `kernel.bin` - Compiled kernel (created after assembly)
- `disk.img` - Disk image containing bootloader + kernel (created by dd)
- `README.md` - This file

## Quick Start

```bash
# Assemble bootloader and kernel
nasm -f bin bootloader.asm -o bootloader.bin
nasm -f bin kernel.asm -o kernel.bin

# Create disk image
dd if=/dev/zero of=disk.img bs=1M count=1
dd if=bootloader.bin of=disk.img bs=512 count=1 conv=notrunc
dd if=kernel.bin of=disk.img bs=512 seek=1 conv=notrunc

# Run in QEMU (as floppy drive)
qemu-system-x86_64 -fda disk.img
```

## Troubleshooting

**"Error: Failed to load kernel!"**
- Ensure both `bootloader.bin` and `kernel.bin` are created
- Verify the disk image was created correctly:
  ```bash
  hexdump -C disk.img | head -20
  ```
- Check that kernel starts at sector 2 with `dd seek=1`
- Ensure `KERNEL_SECTORS` matches your kernel size

**"Kernel loaded but no output"**
- The kernel may not have print functions implemented
- Verify `kernel.asm` has proper BIOS interrupt calls (int 0x10)

**QEMU won't start the bootloader**
- Use floppy drive mode: `qemu-system-x86_64 -fda disk.img`
- Ensure disk.img exists and is at least 1MB
